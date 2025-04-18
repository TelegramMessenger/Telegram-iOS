import Foundation
import UIKit
import Display
import ComponentFlow
import ComponentDisplayAdapters
import AppBundle
import MultilineTextComponent

private let titleFontWithIcon = Font.medium(13.0)
private let titleFontWithoutIcon = Font.regular(17.0)

private final class SwipeOptionsGestureRecognizer: UIPanGestureRecognizer {
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

open class ListItemSwipeOptionContainer: UIView, UIGestureRecognizerDelegate {
    public struct Option: Equatable {
        public enum Icon: Equatable {
            case none
            case image(image: UIImage)
            
            public static func ==(lhs: Icon, rhs: Icon) -> Bool {
                switch lhs {
                case .none:
                    if case .none = rhs {
                        return true
                    } else {
                        return false
                    }
                case let .image(lhsImage):
                    if case let .image(rhsImage) = rhs, lhsImage == rhsImage {
                        return true
                    } else {
                        return false
                    }
                }
            }
        }
        
        public let key: AnyHashable
        public let title: String
        public let icon: Icon
        public let color: UIColor
        public let textColor: UIColor
        
        public init(key: AnyHashable, title: String, icon: Icon, color: UIColor, textColor: UIColor) {
            self.key = key
            self.title = title
            self.icon = icon
            self.color = color
            self.textColor = textColor
        }
        
        public static func ==(lhs: Option, rhs: Option) -> Bool {
            if lhs.key != rhs.key {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if !lhs.color.isEqual(rhs.color) {
                return false
            }
            if !lhs.textColor.isEqual(rhs.textColor) {
                return false
            }
            if lhs.icon != rhs.icon {
                return false
            }
            return true
        }
    }

    private enum OptionAlignment {
        case left
        case right
    }

    private final class OptionView: UIView {
        private let backgroundView: UIView
        private let title = ComponentView<Empty>()
        private var iconView: UIImageView?
        
        private let titleString: String
        private let textColor: UIColor
        
        private var titleSize: CGSize?
        
        var alignment: OptionAlignment?
        var isExpanded: Bool = false
        
        init(title: String, icon: Option.Icon, color: UIColor, textColor: UIColor) {
            self.titleString = title
            self.textColor = textColor
            
            self.backgroundView = UIView()
            
            switch icon {
            case let .image(image):
                let iconView = UIImageView()
                iconView.image = image.withRenderingMode(.alwaysTemplate)
                iconView.tintColor = textColor
                self.iconView = iconView
            case .none:
                self.iconView = nil
            }
            
            super.init(frame: CGRect())
            
            self.addSubview(self.backgroundView)
            if let iconView = self.iconView {
                self.addSubview(iconView)
            }
            self.backgroundView.backgroundColor = color
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func updateLayout(
            isFirst: Bool,
            isLeft: Bool,
            baseSize: CGSize,
            alignment: OptionAlignment,
            isExpanded: Bool,
            extendedWidth: CGFloat,
            sideInset: CGFloat,
            transition: ComponentTransition,
            additive: Bool,
            revealFactor: CGFloat,
            animateIconMovement: Bool
        ) {
            var animateAdditive = false
            if additive && !transition.animation.isImmediate && self.isExpanded != isExpanded {
                animateAdditive = true
            }
            
            let backgroundFrame: CGRect
            if isFirst {
                backgroundFrame = CGRect(origin: CGPoint(x: isLeft ? -400.0 : 0.0, y: 0.0), size: CGSize(width: extendedWidth + 400.0, height: baseSize.height))
            } else {
                backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: extendedWidth, height: baseSize.height))
            }
            let deltaX: CGFloat
            if animateAdditive {
                let previousFrame = self.backgroundView.frame
                self.backgroundView.frame = backgroundFrame
                if isLeft {
                    deltaX = previousFrame.width - backgroundFrame.width
                } else {
                    deltaX = -(previousFrame.width - backgroundFrame.width)
                }
                if !animateIconMovement {
                    transition.animatePosition(view: self.backgroundView, from: CGPoint(x: deltaX, y: 0.0), to: CGPoint(), additive: true)
                }
            } else {
                deltaX = 0.0
                transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            }
            
            self.alignment = alignment
            self.isExpanded = isExpanded
            let titleSize = self.titleSize ?? CGSize(width: 32.0, height: 10.0)
            var contentRect = CGRect(origin: CGPoint(), size: baseSize)
            switch alignment {
            case .left:
                contentRect.origin.x = 0.0
            case .right:
                contentRect.origin.x = extendedWidth - contentRect.width
            }
            
            if let iconView = self.iconView, let imageSize = iconView.image?.size {
                let iconOffset: CGFloat = -9.0
                let titleIconSpacing: CGFloat = 11.0
                let iconFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((baseSize.width - imageSize.width + sideInset) / 2.0), y: contentRect.midY - imageSize.height / 2.0 + iconOffset), size: imageSize)
                if animateAdditive {
                    let iconOffsetX = animateIconMovement ? iconView.frame.minX - iconFrame.minX : deltaX
                    iconView.frame = iconFrame
                    transition.animatePosition(view: iconView, from: CGPoint(x: iconOffsetX, y: 0.0), to: CGPoint(), additive: true)
                } else {
                    transition.setFrame(view: iconView, frame: iconFrame)
                }
                
                let titleFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((baseSize.width - titleSize.width + sideInset) / 2.0), y: contentRect.midY + titleIconSpacing), size: titleSize)
                if let titleView = self.title.view {
                    if titleView.superview == nil {
                        self.addSubview(titleView)
                    }
                    if animateAdditive {
                        let titleOffsetX = animateIconMovement ? titleView.frame.minX - titleFrame.minX : deltaX
                        titleView.frame = titleFrame
                        transition.animatePosition(view: titleView, from: CGPoint(x: titleOffsetX, y: 0.0), to: CGPoint(), additive: true)
                    } else {
                        transition.setFrame(view: titleView, frame: titleFrame)
                    }
                }
            } else {
                let titleFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((baseSize.width - titleSize.width + sideInset) / 2.0), y: contentRect.minY + floor((baseSize.height - titleSize.height) / 2.0)), size: titleSize)
                
                if let titleView = self.title.view {
                    if titleView.superview == nil {
                        self.addSubview(titleView)
                    }
                    if animateAdditive {
                        let titleOffsetX = animateIconMovement ? titleView.frame.minX - titleFrame.minX : deltaX
                        titleView.frame = titleFrame
                        transition.animatePosition(view: titleView, from: CGPoint(x: titleOffsetX, y: 0.0), to: CGPoint(), additive: true)
                    } else {
                        transition.setFrame(view: titleView, frame: titleFrame)
                    }
                }
            }
        }
        
        func calculateSize(_ constrainedSize: CGSize) -> CGSize {
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: self.titleString, font: self.iconView == nil ? titleFontWithoutIcon : titleFontWithIcon, textColor: self.textColor))
                )),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 100.0)
            )
            self.titleSize = titleSize
            
            var maxWidth = titleSize.width
            if let iconView = self.iconView, let image = iconView.image {
                maxWidth = max(image.size.width, maxWidth)
            }
            return CGSize(width: max(74.0, maxWidth + 20.0), height: constrainedSize.height)
        }
    }

    public final class OptionsView: UIView {
        private let optionSelected: (Option) -> Void
        private let tapticAction: () -> Void
        
        private var options: [Option] = []
        private var isLeft: Bool = false
        
        private var optionViews: [OptionView] = []
        private var revealOffset: CGFloat = 0.0
        private var sideInset: CGFloat = 0.0
        
        public init(optionSelected: @escaping (Option) -> Void, tapticAction: @escaping () -> Void) {
            self.optionSelected = optionSelected
            self.tapticAction = tapticAction
            
            super.init(frame: CGRect())
            
            let gestureRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
            gestureRecognizer.tapActionAtPoint = { _ in
                return .waitForSingleTap
            }
            self.addGestureRecognizer(gestureRecognizer)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func setOptions(_ options: [Option], isLeft: Bool) {
            if self.options != options || self.isLeft != isLeft {
                self.options = options
                self.isLeft = isLeft
                for optionView in self.optionViews {
                    optionView.removeFromSuperview()
                }
                self.optionViews = options.map { option in
                    return OptionView(title: option.title, icon: option.icon, color: option.color, textColor: option.textColor)
                }
                if isLeft {
                    for optionView in self.optionViews.reversed() {
                        self.addSubview(optionView)
                    }
                } else {
                    for optionView in self.optionViews {
                        self.addSubview(optionView)
                    }
                }
            }
        }
        
        func calculateSize(_ constrainedSize: CGSize) -> CGSize {
            var maxWidth: CGFloat = 0.0
            for optionView in self.optionViews {
                let nodeSize = optionView.calculateSize(constrainedSize)
                maxWidth = max(nodeSize.width, maxWidth)
            }
            return CGSize(width: maxWidth * CGFloat(self.optionViews.count), height: constrainedSize.height)
        }
        
        public func updateRevealOffset(offset: CGFloat, sideInset: CGFloat, transition: ComponentTransition) {
            self.revealOffset = offset
            self.sideInset = sideInset
            self.updateNodesLayout(transition: transition)
        }
        
        private func updateNodesLayout(transition: ComponentTransition) {
            let size = self.bounds.size
            if size.width.isLessThanOrEqualTo(0.0) || self.optionViews.isEmpty {
                return
            }
            let basicNodeWidth = floor((size.width - abs(self.sideInset)) / CGFloat(self.optionViews.count))
            let lastNodeWidth = size.width - basicNodeWidth * CGFloat(self.optionViews.count - 1)
            let revealFactor = self.revealOffset / size.width
            let boundaryRevealFactor: CGFloat
            if self.optionViews.count > 2 {
                boundaryRevealFactor = 1.0 + 16.0 / size.width
            } else {
                boundaryRevealFactor = 1.0 + basicNodeWidth / size.width
            }
            let startingOffset: CGFloat
            if self.isLeft {
                startingOffset = size.width + max(0.0, abs(revealFactor) - 1.0) * size.width
            } else {
                startingOffset = 0.0
            }
            
            var completionCount = self.optionViews.count
            let intermediateCompletion = {
            }
            
            var i = self.isLeft ? (self.optionViews.count - 1) : 0
            while i >= 0 && i < self.optionViews.count {
                let optionView = self.optionViews[i]
                let nodeWidth = i == (self.optionViews.count - 1) ? lastNodeWidth : basicNodeWidth
                var nodeTransition = transition
                var isExpanded = false
                if (self.isLeft && i == 0) || (!self.isLeft && i == self.optionViews.count - 1) {
                    if abs(revealFactor) > boundaryRevealFactor {
                        isExpanded = true
                    }
                }
                if let _ = optionView.alignment, optionView.isExpanded != isExpanded {
                    nodeTransition = !transition.animation.isImmediate ? transition : .easeInOut(duration: 0.2)
                    if transition.animation.isImmediate {
                        self.tapticAction()
                    }
                }
                
                var sideInset: CGFloat = 0.0
                if i == self.optionViews.count - 1 {
                    sideInset = self.sideInset
                }
                
                let extendedWidth: CGFloat
                let nodeLeftOffset: CGFloat
                if isExpanded {
                    nodeLeftOffset = 0.0
                    extendedWidth = size.width * max(1.0, abs(revealFactor))
                } else if self.isLeft {
                    let offset = basicNodeWidth * CGFloat(self.optionViews.count - 1 - i)
                    extendedWidth = (size.width - offset) * max(1.0, abs(revealFactor))
                    nodeLeftOffset = startingOffset - extendedWidth - floorToScreenPixels(offset * abs(revealFactor))
                } else {
                    let offset = basicNodeWidth * CGFloat(i)
                    extendedWidth = (size.width - offset) * max(1.0, abs(revealFactor))
                    nodeLeftOffset = startingOffset + floorToScreenPixels(offset * abs(revealFactor))
                }
                
                transition.setFrame(view: optionView, frame: CGRect(origin: CGPoint(x: nodeLeftOffset, y: 0.0), size: CGSize(width: extendedWidth, height: size.height)), completion: { _ in
                    completionCount -= 1
                    intermediateCompletion()
                })
                
                var nodeAlignment: OptionAlignment
                if (self.optionViews.count > 1) {
                    nodeAlignment = self.isLeft ? .right : .left
                } else {
                    if self.isLeft {
                        nodeAlignment = isExpanded ? .right : .left
                    } else {
                        nodeAlignment = isExpanded ? .left : .right
                    }
                }
                let animateIconMovement = self.optionViews.count == 1
                optionView.updateLayout(isFirst: (self.isLeft && i == 0) || (!self.isLeft && i == self.optionViews.count - 1), isLeft: self.isLeft, baseSize: CGSize(width: nodeWidth, height: size.height), alignment: nodeAlignment, isExpanded: isExpanded, extendedWidth: extendedWidth, sideInset: sideInset, transition: nodeTransition, additive: transition.animation.isImmediate, revealFactor: revealFactor, animateIconMovement: animateIconMovement)
                
                if self.isLeft {
                    i -= 1
                } else {
                    i += 1
                }
            }
        }
        
        @objc private func tapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
            if case .ended = recognizer.state, let gesture = recognizer.lastRecognizedGestureAndLocation?.0, case .tap = gesture {
                let location = recognizer.location(in: self)
                var selectedOption: Int?
                
                var i = self.isLeft ? 0 : (self.optionViews.count - 1)
                while i >= 0 && i < self.optionViews.count {
                    if self.optionViews[i].frame.contains(location) {
                        selectedOption = i
                        break
                    }
                    if self.isLeft {
                        i += 1
                    } else {
                        i -= 1
                    }
                }
                if let selectedOption {
                    self.optionSelected(self.options[selectedOption])
                }
            }
        }
        
        public func isDisplayingExtendedAction() -> Bool {
            return self.optionViews.contains(where: { $0.isExpanded })
        }
    }
    
    private var validLayout: (size: CGSize, leftInset: CGFloat, reftInset: CGFloat)?
    
    private var leftRevealView: OptionsView?
    private var rightRevealView: OptionsView?
    private var revealOptions: (left: [Option], right: [Option]) = ([], [])
    
    private var initialRevealOffset: CGFloat = 0.0
    public private(set) var revealOffset: CGFloat = 0.0
    
    private var recognizer: SwipeOptionsGestureRecognizer?
    private var tapRecognizer: UITapGestureRecognizer?
    private var hapticFeedback: HapticFeedback?
    
    private var allowAnyDirection: Bool = false
    
    public var updateRevealOffset: ((CGFloat, ComponentTransition) -> Void)?
    public var revealOptionsInteractivelyOpened: (() -> Void)?
    public var revealOptionsInteractivelyClosed: (() -> Void)?
    public var revealOptionSelected: ((Option, Bool) -> Void)?
    
    open var controlsContainer: UIView {
        return self
    }
    
    public var isDisplayingRevealedOptions: Bool {
        return !self.revealOffset.isZero
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        let recognizer = SwipeOptionsGestureRecognizer(target: self, action: #selector(self.revealGesture(_:)))
        self.recognizer = recognizer
        recognizer.delegate = self
        recognizer.allowAnyDirection = self.allowAnyDirection
        self.addGestureRecognizer(recognizer)
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.revealTapGesture(_:)))
        self.tapRecognizer = tapRecognizer
        tapRecognizer.delegate = self
        self.addGestureRecognizer(tapRecognizer)
        
        self.disablesInteractiveTransitionGestureRecognizer = self.allowAnyDirection
        
        self.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
            guard let self else {
                return false
            }
            if !self.revealOffset.isZero {
                return true
            }
            return false
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func setRevealOptions(_ options: (left: [Option], right: [Option])) {
        if self.revealOptions == options {
            return
        }
        let previousOptions = self.revealOptions
        let wasEmpty = self.revealOptions.left.isEmpty && self.revealOptions.right.isEmpty
        self.revealOptions = options
        let isEmpty = options.left.isEmpty && options.right.isEmpty
        if options.left.isEmpty {
            if let _ = self.leftRevealView {
                self.recognizer?.becomeCancelled()
                self.updateRevealOffsetInternal(offset: 0.0, transition: .spring(duration: 0.3))
            }
        } else if previousOptions.left != options.left {
        }
        if options.right.isEmpty {
            if let _ = self.rightRevealView {
                self.recognizer?.becomeCancelled()
                self.updateRevealOffsetInternal(offset: 0.0, transition: .spring(duration: 0.3))
            }
        } else if previousOptions.right != options.right {
            if let _ = self.rightRevealView {
            }
        }
        if wasEmpty != isEmpty {
            self.recognizer?.isEnabled = !isEmpty
        }
        let allowAnyDirection = !options.left.isEmpty || !self.revealOffset.isZero
        if allowAnyDirection != self.allowAnyDirection {
            self.allowAnyDirection = allowAnyDirection
            self.recognizer?.allowAnyDirection = allowAnyDirection
            self.disablesInteractiveTransitionGestureRecognizer = allowAnyDirection
        }
    }
    
    override open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let recognizer = self.recognizer, gestureRecognizer == self.tapRecognizer {
            return abs(self.revealOffset) > 0.0 && !recognizer.validatedGesture
        } else if let recognizer = self.recognizer, gestureRecognizer == self.recognizer, recognizer.numberOfTouches == 0 {
            let translation = recognizer.velocity(in: recognizer.view)
            if abs(translation.y) > 4.0 && abs(translation.y) > abs(translation.x) * 2.5 {
                return false
            }
        }
        return true
    }
    
    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let recognizer = self.recognizer, otherGestureRecognizer == recognizer {
            return true
        } else {
            return false
        }
    }
    
    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        /*if gestureRecognizer === self.recognizer && otherGestureRecognizer is InteractiveTransitionGestureRecognizer {
            return true
        }*/
        return false
    }
    
    @objc private func revealTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.updateRevealOffsetInternal(offset: 0.0, transition: .spring(duration: 0.3))
            self.revealOptionsInteractivelyClosed?()
        }
    }

    @objc private func revealGesture(_ recognizer: SwipeOptionsGestureRecognizer) {
        guard let (size, _, _) = self.validLayout else {
            return
        }
        switch recognizer.state {
            case .began:
                if let leftRevealView = self.leftRevealView {
                    let revealSize = leftRevealView.bounds.size
                    let location = recognizer.location(in: self)
                    if location.x < revealSize.width {
                        recognizer.becomeCancelled()
                    } else {
                        self.initialRevealOffset = self.revealOffset
                    }
                } else if let rightRevealView = self.rightRevealView {
                    let revealSize = rightRevealView.bounds.size
                    let location = recognizer.location(in: self)
                    if location.x > size.width - revealSize.width {
                        recognizer.becomeCancelled()
                    } else {
                        self.initialRevealOffset = self.revealOffset
                    }
                } else {
                    if self.revealOptions.left.isEmpty && self.revealOptions.right.isEmpty {
                        recognizer.becomeCancelled()
                    }
                    self.initialRevealOffset = self.revealOffset
                }
            case .changed:
                var translation = recognizer.translation(in: self)
                translation.x += self.initialRevealOffset
                if self.revealOptions.left.isEmpty {
                    translation.x = min(0.0, translation.x)
                }
                if self.leftRevealView == nil && CGFloat(0.0).isLess(than: translation.x) {
                    self.setupAndAddLeftRevealNode()
                    self.revealOptionsInteractivelyOpened?()
                } else if self.rightRevealView == nil && translation.x.isLess(than: 0.0) {
                    self.setupAndAddRightRevealNode()
                    self.revealOptionsInteractivelyOpened?()
                }
                self.updateRevealOffsetInternal(offset: translation.x, transition: .immediate)
                if self.leftRevealView == nil && self.rightRevealView == nil {
                    self.revealOptionsInteractivelyClosed?()
                }
            case .ended, .cancelled:
                guard let recognizer = self.recognizer else {
                    break
                }
                
                if let leftRevealView = self.leftRevealView {
                    let velocity = recognizer.velocity(in: self)
                    let revealSize = leftRevealView.bounds.size
                    var reveal = false
                    if abs(velocity.x) < 100.0 {
                        if self.initialRevealOffset.isZero && self.revealOffset > 0.0 {
                            reveal = true
                        } else if self.revealOffset > revealSize.width {
                            reveal = true
                        } else {
                            reveal = false
                        }
                    } else {
                        if velocity.x > 0.0 {
                            reveal = true
                        } else {
                            reveal = false
                        }
                    }
                    
                    var selectedOption: Option?
                    if reveal && leftRevealView.isDisplayingExtendedAction() {
                        reveal = false
                        selectedOption = self.revealOptions.left.first
                    } else {
                        self.updateRevealOffsetInternal(offset: reveal ? revealSize.width : 0.0, transition: .spring(duration: 0.3))
                    }
            
                    if let selectedOption = selectedOption {
                        self.revealOptionSelected?(selectedOption, true)
                    } else {
                        if !reveal {
                            self.revealOptionsInteractivelyClosed?()
                        }
                    }
                } else if let rightRevealView = self.rightRevealView {
                    let velocity = recognizer.velocity(in: self)
                    let revealSize = rightRevealView.bounds.size
                    var reveal = false
                    if abs(velocity.x) < 100.0 {
                        if self.initialRevealOffset.isZero && self.revealOffset < 0.0 {
                            reveal = true
                        } else if self.revealOffset < -revealSize.width {
                            reveal = true
                        } else {
                            reveal = false
                        }
                    } else {
                        if velocity.x < 0.0 {
                            reveal = true
                        } else {
                            reveal = false
                        }
                    }
                    
                    var selectedOption: Option?
                    if reveal && rightRevealView.isDisplayingExtendedAction() {
                        reveal = false
                        selectedOption = self.revealOptions.right.last
                    } else {
                        self.updateRevealOffsetInternal(offset: reveal ? -revealSize.width : 0.0, transition: .spring(duration: 0.3))
                    }
                    
                    if let selectedOption = selectedOption {
                        self.revealOptionSelected?(selectedOption, true)
                    } else {
                        if !reveal {
                            self.revealOptionsInteractivelyClosed?()
                        }
                    }
                }
            default:
                break
        }
    }
    
    private func setupAndAddLeftRevealNode() {
        if !self.revealOptions.left.isEmpty {
            let revealView = OptionsView(optionSelected: { [weak self] option in
                self?.revealOptionSelected?(option, false)
            }, tapticAction: { [weak self] in
                self?.hapticImpact()
            })
            revealView.setOptions(self.revealOptions.left, isLeft: true)
            self.leftRevealView = revealView
            
            if let (size, leftInset, _) = self.validLayout {
                var revealSize = revealView.calculateSize(CGSize(width: CGFloat.greatestFiniteMagnitude, height: size.height))
                revealSize.width += leftInset
                
                revealView.frame = CGRect(origin: CGPoint(x: min(self.revealOffset - revealSize.width, 0.0), y: 0.0), size: revealSize)
                revealView.updateRevealOffset(offset: 0.0, sideInset: leftInset, transition: .immediate)
            }
            
            self.controlsContainer.addSubview(revealView)
        }
    }
    
    private func setupAndAddRightRevealNode() {
        if !self.revealOptions.right.isEmpty {
            let revealView = OptionsView(optionSelected: { [weak self] option in
                self?.revealOptionSelected?(option, false)
            }, tapticAction: { [weak self] in
                self?.hapticImpact()
            })
            revealView.setOptions(self.revealOptions.right, isLeft: false)
            self.rightRevealView = revealView
            
            if let (size, _, rightInset) = self.validLayout {
                var revealSize = revealView.calculateSize(CGSize(width: CGFloat.greatestFiniteMagnitude, height: size.height))
                revealSize.width += rightInset
                
                revealView.frame = CGRect(origin: CGPoint(x: size.width + max(self.revealOffset, -revealSize.width), y: 0.0), size: revealSize)
                revealView.updateRevealOffset(offset: 0.0, sideInset: -rightInset, transition: .immediate)
            }
            
            self.controlsContainer.addSubview(revealView)
        }
    }
    
    public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
        self.validLayout = (size, leftInset, rightInset)
        
        if let leftRevealView = self.leftRevealView {
            var revealSize = leftRevealView.calculateSize(CGSize(width: CGFloat.greatestFiniteMagnitude, height: size.height))
            revealSize.width += leftInset
            leftRevealView.frame = CGRect(origin: CGPoint(x: min(self.revealOffset - revealSize.width, 0.0), y: 0.0), size: revealSize)
        }
        
        if let rightRevealView = self.rightRevealView {
            var revealSize = rightRevealView.calculateSize(CGSize(width: CGFloat.greatestFiniteMagnitude, height: size.height))
            revealSize.width += rightInset
            rightRevealView.frame = CGRect(origin: CGPoint(x: size.width + max(self.revealOffset, -revealSize.width), y: 0.0), size: revealSize)
        }
    }
    
    open func updateRevealOffsetInternal(offset: CGFloat, transition: ComponentTransition, completion: (() -> Void)? = nil) {
        self.revealOffset = offset
        guard let (size, leftInset, rightInset) = self.validLayout else {
            return
        }
        
        var leftRevealCompleted = true
        var rightRevealCompleted = true
        let intermediateCompletion = {
            if leftRevealCompleted && rightRevealCompleted {
                completion?()
            }
        }
        
        if let leftRevealView = self.leftRevealView {
            leftRevealCompleted = false
            
            let revealSize = leftRevealView.bounds.size
            
            let revealFrame = CGRect(origin: CGPoint(x: min(self.revealOffset - revealSize.width, 0.0), y: 0.0), size: revealSize)
            let revealNodeOffset = -self.revealOffset
            leftRevealView.updateRevealOffset(offset: revealNodeOffset, sideInset: leftInset, transition: transition)
            
            if CGFloat(offset).isLessThanOrEqualTo(0.0) {
                self.leftRevealView = nil
                transition.setFrame(view: leftRevealView, frame: revealFrame, completion: { [weak leftRevealView] _ in
                    leftRevealView?.removeFromSuperview()
                    
                    leftRevealCompleted = true
                    intermediateCompletion()
                })
            } else {
                transition.setFrame(view: leftRevealView, frame: revealFrame, completion: { _ in
                    leftRevealCompleted = true
                    intermediateCompletion()
                })
            }
        }
        if let rightRevealView = self.rightRevealView {
            rightRevealCompleted = false
            
            let revealSize = rightRevealView.bounds.size
            
            let revealFrame = CGRect(origin: CGPoint(x: min(size.width, size.width + self.revealOffset), y: 0.0), size: revealSize)
            let revealNodeOffset = -self.revealOffset
            rightRevealView.updateRevealOffset(offset: revealNodeOffset, sideInset: -rightInset, transition: transition)
            
            if CGFloat(0.0).isLessThanOrEqualTo(offset) {
                self.rightRevealView = nil
                transition.setFrame(view: rightRevealView, frame: revealFrame, completion: { [weak rightRevealView] _ in
                    rightRevealView?.removeFromSuperview()
                    
                    rightRevealCompleted = true
                    intermediateCompletion()
                })
            } else {
                transition.setFrame(view: rightRevealView, frame: revealFrame, completion: { _ in
                    rightRevealCompleted = true
                    intermediateCompletion()
                })
            }
        }
        let allowAnyDirection = !self.revealOptions.left.isEmpty || !offset.isZero
        if allowAnyDirection != self.allowAnyDirection {
            self.allowAnyDirection = allowAnyDirection
            self.recognizer?.allowAnyDirection = allowAnyDirection
            self.disablesInteractiveTransitionGestureRecognizer = allowAnyDirection
        }
        
        self.updateRevealOffset?(offset, transition)
    }
    
    open func setRevealOptionsOpened(_ value: Bool, animated: Bool) {
        if value != !self.revealOffset.isZero {
            if !self.revealOffset.isZero {
                self.recognizer?.becomeCancelled()
            }
            let transition: ComponentTransition
            if animated {
                transition = .spring(duration: 0.3)
            } else {
                transition = .immediate
            }
            if value {
                if self.rightRevealView == nil {
                    self.setupAndAddRightRevealNode()
                    if let rightRevealView = self.rightRevealView, let validLayout = self.validLayout {
                        let revealSize = rightRevealView.calculateSize(CGSize(width: CGFloat.greatestFiniteMagnitude, height: validLayout.size.height))
                        self.updateRevealOffsetInternal(offset: -revealSize.width, transition: transition)
                    }
                }
            } else if !self.revealOffset.isZero {
                self.updateRevealOffsetInternal(offset: 0.0, transition: transition)
            }
        }
    }
    
    open func animateRevealOptionsFill(completion: (() -> Void)? = nil) {
        if let validLayout = self.validLayout {
            self.layer.allowsGroupOpacity = true
            self.updateRevealOffsetInternal(offset: -validLayout.0.width - 74.0, transition: .spring(duration: 0.3), completion: {
                self.layer.allowsGroupOpacity = false
                completion?()
            })
        }
    }
    
    open var preventsTouchesToOtherItems: Bool {
        return self.isDisplayingRevealedOptions
    }
    
    open func touchesToOtherItemsPrevented() {
        if self.isDisplayingRevealedOptions {
            self.setRevealOptionsOpened(false, animated: true)
        }
    }
    
    private func hapticImpact() {
        if self.hapticFeedback == nil {
            self.hapticFeedback = HapticFeedback()
        }
        self.hapticFeedback?.impact(.medium)
    }
}
