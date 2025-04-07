import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import BalancedTextComponent
import TelegramPresentationData
import CallsEmoji

private final class EmojiContainerView: UIView {
    private let maskImageView: UIImageView?
    let contentView: UIView

    var isMaskEnabled: Bool = false {
        didSet {
            if self.isMaskEnabled != oldValue {
                if self.isMaskEnabled {
                    self.mask = self.maskImageView
                } else {
                    self.mask = nil
                }
            }
        }
    }

    init(hasMask: Bool) {
        if hasMask {
            self.maskImageView = UIImageView()
        } else {
            self.maskImageView = nil
        }

        self.contentView = UIView()
        self.contentView.layer.anchorPoint = CGPoint(x: 0.0, y: 0.0)
        self.contentView.center = CGPoint(x: 0.0, y: 0.0)

        super.init(frame: CGRect())
        
        if let maskImageView = self.maskImageView {
            self.mask = maskImageView
        }
        self.addSubview(self.contentView)
        self.clipsToBounds = hasMask
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(size: CGSize, borderWidth: CGFloat) {
        let minimalHeight = borderWidth * 2.0 + 1.0
        let minimalSize = CGSize(width: 4.0, height: minimalHeight)

        if let maskImageView = self.maskImageView, maskImageView.image?.size != minimalSize {
            let generatedImage = generateImage(minimalSize, rotatedContext: { imageSize, context in
                context.clear(CGRect(origin: CGPoint(), size: imageSize))

                let height: CGFloat = borderWidth
                let baseGradientAlpha: CGFloat = 1.0
                let numSteps = 8
                let firstStep = 0
                let firstLocation = 0.0
                let colors = (0 ..< numSteps).map { i -> UIColor in
                    if i < firstStep {
                        return UIColor(white: 1.0, alpha: 1.0)
                    } else {
                        let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                        let value: CGFloat = bezierPoint(0.42, 0.0, 0.58, 1.0, step)
                        return UIColor(white: 1.0, alpha: baseGradientAlpha * value)
                    }
                }
                var locations = (0 ..< numSteps).map { i -> CGFloat in
                    if i < firstStep {
                        return 0.0
                    } else {
                        let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                        return (firstLocation + (1.0 - firstLocation) * step)
                    }
                }

                let gradient = CGGradient(colorsSpace: DeviceGraphicsContextSettings.shared.colorSpace, colors: colors.map { $0.cgColor } as CFArray, locations: &locations)!

                context.setFillColor(UIColor.white.cgColor)
                context.fill(CGRect(origin: CGPoint(x: 0.0, y: height), size: CGSize(width: imageSize.width, height: 1.0)))

                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: height), options: CGGradientDrawingOptions())
                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: imageSize.height), end: CGPoint(x: 0.0, y: imageSize.height - height), options: CGGradientDrawingOptions())
            })

            let capInsets = UIEdgeInsets(top: borderWidth, left: 0, bottom: borderWidth, right: 0)
            maskImageView.image = generatedImage?.resizableImage(withCapInsets: capInsets, resizingMode: .stretch)
        }
        if let maskImageView = self.maskImageView {
            maskImageView.frame = CGRect(origin: CGPoint(), size: size)
        }
        self.contentView.bounds = CGRect(origin: CGPoint(), size: size)
    }
}

private final class EmojiItemComponent: Component {
    let emoji: String?

    init(emoji: String?) {
        self.emoji = emoji
    }

    static func ==(lhs: EmojiItemComponent, rhs: EmojiItemComponent) -> Bool {
        if lhs.emoji != rhs.emoji {
            return false
        }
        return true
    }

    final class View: UIView {
        private let containerView: EmojiContainerView
        private let measureEmojiView = ComponentView<Empty>()
        private var pendingContainerView: EmojiContainerView?
        private var pendingEmojiViews: [ComponentView<Empty>] = []
        private var emojiView: ComponentView<Empty>?

        private var component: EmojiItemComponent?
        private weak var state: EmptyComponentState?
        
        private var pendingEmojiValues: [String]?

        override init(frame: CGRect) {
            self.containerView = EmojiContainerView(hasMask: true)

            super.init(frame: frame)

            self.addSubview(self.containerView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
        }

        func update(component: EmojiItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let pendingContainerInset: CGFloat = 6.0

            self.component = component
            self.state = state

            let size = self.measureEmojiView.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "👍", font: Font.regular(40.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 200.0)
            )

            let containerFrame = CGRect(origin: CGPoint(x: -pendingContainerInset, y: -pendingContainerInset), size: CGSize(width: size.width + pendingContainerInset * 2.0, height: size.height + pendingContainerInset * 2.0))
            self.containerView.frame = containerFrame
            self.containerView.update(size: containerFrame.size, borderWidth: 12.0)

            /*let maxBlur: CGFloat = 4.0
            if component.emoji == nil, (self.containerView.contentView.layer.filters == nil || self.containerView.contentView.layer.filters?.count == 0) {
                if let blurFilter = CALayer.blur() {
                    blurFilter.setValue(maxBlur as NSNumber, forKey: "inputRadius")
                    self.containerView.contentView.layer.filters = [blurFilter]
                    self.containerView.contentView.layer.animate(from: 0.0 as NSNumber, to: maxBlur as NSNumber, keyPath: "filters.gaussianBlur.inputRadius", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2, removeOnCompletion: true)
                }
            } else if self.containerView.contentView.layer.filters != nil && self.containerView.contentView.layer.filters?.count != 0 {
                if let blurFilter = CALayer.blur() {
                    blurFilter.setValue(0.0 as NSNumber, forKey: "inputRadius")
                    self.containerView.contentView.layer.filters = [blurFilter]
                    self.containerView.contentView.layer.animate(from: maxBlur as NSNumber, to: 0.0 as NSNumber, keyPath: "filters.gaussianBlur.inputRadius", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2, removeOnCompletion: false, completion: { [weak self] flag in
                        if flag, let self {
                            self.containerView.contentView.layer.filters = nil
                        }
                    })
                }
            }*/
            
            let borderEmoji = 2
            let numEmoji = borderEmoji * 2 + 3

            var previousEmojiView: ComponentView<Empty>?

            if let emoji = component.emoji {
                let emojiView: ComponentView<Empty>
                var emojiViewTransition = transition
                if let current = self.emojiView {
                    emojiView = current
                } else {
                    emojiViewTransition = .immediate
                    emojiView = ComponentView()
                    self.emojiView = emojiView
                }
                let emojiSize = emojiView.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: emoji, font: Font.regular(40.0), textColor: .white))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 200.0)
                )
                let emojiFrame = CGRect(origin: CGPoint(x: pendingContainerInset + floor((size.width - emojiSize.width) * 0.5), y: pendingContainerInset + floor((size.height - emojiSize.height) * 0.5)), size: emojiSize)
                if let emojiComponentView = emojiView.view {
                    if emojiComponentView.superview == nil {
                        self.containerView.contentView.addSubview(emojiComponentView)
                    }
                    emojiViewTransition.setFrame(view: emojiComponentView, frame: emojiFrame)

                    if let pendingContainerView = self.pendingContainerView {
                        self.pendingContainerView = nil
                        self.pendingEmojiViews.removeAll()

                        let currentPendingContainerOffset = pendingContainerView.contentView.layer.presentation()?.position.y ?? pendingContainerView.contentView.layer.position.y
                        
                        pendingContainerView.contentView.layer.removeAnimation(forKey: "offsetCycle")
                        pendingContainerView.contentView.layer.position.y = currentPendingContainerOffset

                        let animateTransition: ComponentTransition = .spring(duration: 0.4)
                        let targetOffset: CGFloat = CGFloat(borderEmoji - 1) * size.height
                        animateTransition.setPosition(layer: pendingContainerView.contentView.layer, position: CGPoint(x: 0.0, y: targetOffset), completion: { [weak self, weak pendingContainerView] _ in
                            pendingContainerView?.removeFromSuperview()

                            self?.containerView.isMaskEnabled = false
                        })

                        animateTransition.animatePosition(view: emojiComponentView, from: CGPoint(x: 0.0, y: currentPendingContainerOffset - targetOffset), to: CGPoint(), additive: true)
                    } else {
                        self.containerView.isMaskEnabled = false
                    }
                }
                
                self.pendingEmojiValues = nil
            } else {
                if let emojiView = self.emojiView {
                    self.emojiView = nil
                    previousEmojiView = emojiView
                }
                
                if self.pendingEmojiValues?.count != numEmoji {
                    var pendingEmojiValuesValue: [String] = []
                    for _ in 0 ..< numEmoji - borderEmoji - 1 {
                        pendingEmojiValuesValue.append(randomCallsEmoji() ?? "👍")
                    }
                    for i in 0 ..< borderEmoji + 1 {
                        pendingEmojiValuesValue.append(pendingEmojiValuesValue[i])
                    }
                    self.pendingEmojiValues = pendingEmojiValuesValue
                }
            }

            if let pendingEmojiValues, pendingEmojiValues.count == numEmoji {
                self.containerView.isMaskEnabled = true
                
                let pendingContainerView: EmojiContainerView
                if let current = self.pendingContainerView {
                    pendingContainerView = current
                } else {
                    pendingContainerView = EmojiContainerView(hasMask: false)
                    self.pendingContainerView = pendingContainerView
                }

                for i in 0 ..< numEmoji {
                    let pendingEmojiView: ComponentView<Empty>
                    if self.pendingEmojiViews.count > i {
                        pendingEmojiView = self.pendingEmojiViews[i]
                    } else {
                        pendingEmojiView = ComponentView()
                        self.pendingEmojiViews.append(pendingEmojiView)
                    }
                    let pendingEmojiViewSize = pendingEmojiView.update(
                        transition: .immediate,
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: pendingEmojiValues[i], font: Font.regular(40.0), textColor: .white))
                        )),
                        environment: {},
                        containerSize: CGSize(width: 200.0, height: 200.0)
                    )
                    if let pendingEmojiComponentView = pendingEmojiView.view {
                        if pendingEmojiComponentView.superview == nil {
                            pendingContainerView.contentView.addSubview(pendingEmojiComponentView)
                        }
                        pendingEmojiComponentView.frame = CGRect(origin: CGPoint(x: pendingContainerInset, y: pendingContainerInset + CGFloat(i) * size.height), size: pendingEmojiViewSize)
                    }
                }

                pendingContainerView.frame = CGRect(origin: CGPoint(), size: containerFrame.size)
                pendingContainerView.update(size: containerFrame.size, borderWidth: 12.0)

                if pendingContainerView.superview == nil {
                    self.containerView.contentView.addSubview(pendingContainerView)

                    let startTime = CACurrentMediaTime()

                    var loopAnimationOffset: Double = 0.0
                    if let previousEmojiComponentView = previousEmojiView?.view {
                        previousEmojiView = nil

                        pendingContainerView.contentView.addSubview(previousEmojiComponentView)
                        previousEmojiComponentView.center = previousEmojiComponentView.center.offsetBy(dx: 0.0, dy: CGFloat(numEmoji) * size.height)

                        let animation = CABasicAnimation(keyPath: "position.y")
                        loopAnimationOffset = 0.25
                        animation.duration = loopAnimationOffset
                        animation.fromValue = -CGFloat(numEmoji) * size.height
                        animation.toValue = 0.0
                        animation.timingFunction = CAMediaTimingFunction(name: .easeIn)
                        animation.autoreverses = false
                        animation.repeatCount = 1.0
                        animation.fillMode = .backwards
                        animation.isRemovedOnCompletion = true
                        animation.beginTime = pendingContainerView.contentView.layer.convertTime(startTime, from: nil)
                        animation.isAdditive = true

                        animation.completion = { [weak previousEmojiComponentView] _ in
                            previousEmojiComponentView?.removeFromSuperview()
                        }
                        
                        pendingContainerView.contentView.layer.add(animation, forKey: "offsetCyclePre")
                    } 

                    let animation = CABasicAnimation(keyPath: "position.y")
                    animation.duration = 0.2
                    animation.fromValue = -CGFloat(numEmoji - borderEmoji) * size.height
                    animation.toValue = CGFloat(borderEmoji - 3) * size.height
                    animation.timingFunction = CAMediaTimingFunction(name: .linear)
                    animation.autoreverses = false
                    animation.repeatCount = .infinity
                    animation.fillMode = .forwards

                    animation.beginTime = pendingContainerView.contentView.layer.convertTime(startTime + loopAnimationOffset, from: nil)
                    
                    pendingContainerView.contentView.layer.add(animation, forKey: "offsetCycle")
                } else if pendingContainerView.contentView.layer.animation(forKey: "offsetCycle") == nil {
                    let animation = CABasicAnimation(keyPath: "position.y")
                    animation.duration = 0.2
                    animation.fromValue = -CGFloat(numEmoji - borderEmoji) * size.height
                    animation.toValue = CGFloat(borderEmoji - 3) * size.height
                    animation.timingFunction = CAMediaTimingFunction(name: .linear)
                    animation.autoreverses = false
                    animation.repeatCount = .infinity
                    animation.fillMode = .forwards

                    pendingContainerView.contentView.layer.add(animation, forKey: "offsetCycle")
                }
            } else if let pendingContainerView = self.pendingContainerView {
                self.pendingContainerView = nil
                pendingContainerView.removeFromSuperview()

                for emojiView in self.pendingEmojiViews {
                    emojiView.view?.removeFromSuperview()
                }
                self.pendingEmojiViews.removeAll()
            }

            if let previousEmojiView {
                previousEmojiView.view?.removeFromSuperview()
            }

            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class VideoChatEncryptionKeyComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let emoji: [String]
    let isExpanded: Bool
    let tapAction: () -> Void

    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        emoji: [String],
        isExpanded: Bool,
        tapAction: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.emoji = emoji
        self.isExpanded = isExpanded
        self.tapAction = tapAction
    }

    static func ==(lhs: VideoChatEncryptionKeyComponent, rhs: VideoChatEncryptionKeyComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.emoji != rhs.emoji {
            return false
        }
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        return true
    }

    final class View: UIView {
        private let containerView: UIView
        private var emojiItems: [ComponentView<Empty>] = []
        private let background = ComponentView<Empty>()
        private let backgroundShadowLayer = SimpleLayer()
        private let collapsedText = ComponentView<Empty>()
        private let expandedText = ComponentView<Empty>()
        private let expandedSeparatorLayer = SimpleLayer()
        private let expandedButtonText = ComponentView<Empty>()

        private var component: VideoChatEncryptionKeyComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private var tapRecognizer: TapLongTapOrDoubleTapGestureRecognizer?

        #if DEBUG
        private var mockStateTimer: Foundation.Timer?
        private var mockCurrentKey: [String]?
        #endif
        
        override init(frame: CGRect) {
            self.containerView = UIView()
            self.containerView.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.addSubview(self.containerView)
            
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
            self.addGestureRecognizer(tapRecognizer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.mockStateTimer?.invalidate()
        }
        
        @objc private func tapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = recognizer.state {
                component.tapAction()
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if self.containerView.frame.contains(point) {
                return self
            } else {
                return nil
            }
        }
        
        func update(component: VideoChatEncryptionKeyComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            #if DEBUG && false
            if self.component == nil {
                self.mockStateTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true, block: { [weak self] _ in
                    guard let self else {
                        return
                    }

                    if self.mockCurrentKey == nil {
                        self.mockCurrentKey = (0 ..< 4).map { _ in randomCallsEmoji() ?? "👍" }
                    } else {
                        self.mockCurrentKey = nil
                    }

                    if !self.isUpdating {
                        self.state?.updated(transition: .spring(duration: 0.4), isLocal: true)
                    }
                })
            }
            let emoji = self.mockCurrentKey ?? []
            #else
            let emoji = component.emoji
            #endif
            
            self.component = component
            self.state = state
            
            let alphaTransition: ComponentTransition
            if transition.animation.isImmediate {
                alphaTransition = .immediate
            } else {
                alphaTransition = .easeInOut(duration: 0.25)
            }
            
            let collapsedSideInset: CGFloat = 7.0
            let collapsedVerticalInset: CGFloat = 8.0
            let collapsedEmojiSpacing: CGFloat = 0.0
            let collapsedEmojiTextSpacing: CGFloat = 5.0
            
            let expandedTopInset: CGFloat = 8.0
            let expandedSideInset: CGFloat = 14.0
            var expandedEmojiSpacing: CGFloat = 10.0
            let expandedEmojiTextSpacing: CGFloat = 10.0
            let expandedTextButtonSpacing: CGFloat = 10.0
            let expandedButtonTopInset: CGFloat = 12.0
            let expandedButtonBottomInset: CGFloat = 13.0
            
            let emojiItemSizes = (0 ..< 4).map { i -> CGSize in
                let emojiItem: ComponentView<Empty>
                if self.emojiItems.count > i {
                    emojiItem = self.emojiItems[i]
                } else {
                    emojiItem = ComponentView()
                    self.emojiItems.append(emojiItem)
                }
                return emojiItem.update(
                    transition: transition,
                    component: AnyComponent(EmojiItemComponent(
                        emoji: i < emoji.count ? emoji[i] : nil
                    )),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 200.0)
                )
            }
            
            //TODO:localize
            let collapsedTextSize = self.collapsedText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "End-to-end encrypted", font: Font.semibold(12.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: 1000.0, height: 1000.0)
            )
            
            let expandedTextSize = self.expandedText.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(string: "These four emojis represent the call's encryption key. They must match for all participants and change when someone joins or leaves.", font: Font.regular(12.0), textColor: component.theme.list.itemPrimaryTextColor)),
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.3
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - expandedSideInset * 2.0, height: 1000.0)
            )
            
            let expandedButtonTextSize = self.expandedButtonText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "Close", font: Font.regular(17.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - expandedSideInset * 2.0, height: 1000.0)
            )
            
            let collapsedEmojiFactor: CGFloat = 20.0 / 40.0
            let collapsedEmojiSizes = emojiItemSizes.map { CGSize(width: floor($0.width * collapsedEmojiFactor), height: floor($0.height * collapsedEmojiFactor)) }
            
            let collapsedSize = CGSize(width: collapsedTextSize.width + collapsedSideInset * 2.0 + collapsedEmojiTextSpacing * 2.0 + collapsedEmojiSpacing + collapsedEmojiSizes.reduce(into: 0.0, { $0 += $1.width }), height: collapsedTextSize.height + collapsedVerticalInset * 2.0)
            
            var expandedEmojiWidth = expandedEmojiSpacing * CGFloat(self.emojiItems.count - 1) + emojiItemSizes.reduce(into: 0.0, { $0 += $1.width })
            
            var expandedSize = CGSize(width: expandedSideInset * 2.0, height: 0.0)
            
            expandedSize.width += max(expandedTextSize.width, expandedEmojiWidth)
            
            expandedSize.height += expandedTopInset
            expandedSize.height += emojiItemSizes[0].height
            expandedSize.height += expandedEmojiTextSpacing
            expandedSize.height += expandedTextSize.height
            expandedSize.height += expandedTextButtonSpacing
            expandedSize.height += expandedButtonTopInset
            expandedSize.height += expandedButtonTextSize.height
            expandedSize.height += expandedButtonBottomInset
            
            if expandedEmojiWidth < expandedSize.width - expandedSideInset * 2.0 {
                expandedEmojiWidth = expandedSize.width - expandedSideInset * 2.0
                
                let cleanEmojiWidth = emojiItemSizes.reduce(into: 0.0, { $0 += $1.width })
                expandedEmojiSpacing = floorToScreenPixels((expandedEmojiWidth - cleanEmojiWidth) / CGFloat(self.emojiItems.count - 1))
                expandedEmojiSpacing = min(expandedEmojiSpacing, 24.0)    
                expandedEmojiWidth = expandedEmojiSpacing * CGFloat(self.emojiItems.count - 1) + emojiItemSizes.reduce(into: 0.0, { $0 += $1.width })
            }
            
            let backgroundSize = component.isExpanded ? expandedSize : collapsedSize
            let backgroundCornerRadius: CGFloat = component.isExpanded ? 10.0 : collapsedSize.height * 0.5
            
            let _ = self.background.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(
                    color: component.theme.list.itemBlocksBackgroundColor,
                    cornerRadius: .value(backgroundCornerRadius), smoothCorners: false
                )),
                environment: {},
                containerSize: backgroundSize
            )
            let backgroundFrame = CGRect(origin: CGPoint(), size: backgroundSize)
            
            if self.backgroundShadowLayer.superlayer == nil {
                self.backgroundShadowLayer.backgroundColor = UIColor.clear.cgColor
                self.containerView.layer.addSublayer(self.backgroundShadowLayer)
            }
            self.backgroundShadowLayer.shadowOpacity = 0.3
            self.backgroundShadowLayer.shadowColor = UIColor.black.cgColor
            self.backgroundShadowLayer.shadowRadius = 5.0
            self.backgroundShadowLayer.shadowOffset = CGSize(width: 0.0, height: 2.0)
            alphaTransition.setAlpha(layer: self.backgroundShadowLayer, alpha: component.isExpanded ? 1.0 : 0.0)
            
            transition.setFrame(layer: self.backgroundShadowLayer, frame: backgroundFrame)
            transition.setCornerRadius(layer: self.backgroundShadowLayer, cornerRadius: backgroundCornerRadius)
            transition.setShadowPath(layer: self.backgroundShadowLayer, path: UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: backgroundFrame.size), cornerRadius: backgroundCornerRadius).cgPath)
            
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    self.containerView.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: backgroundFrame)
            }
            
            var collapsedEmojiLeftOffset = collapsedSideInset
            var collapsedEmojiRightOffset = collapsedSize.width - collapsedSideInset
            
            for i in 0 ..< self.emojiItems.count {
                let mappedIndex: Int
                if i < 2 {
                    mappedIndex = i
                } else {
                    mappedIndex = self.emojiItems.count - (i - 1)
                }
                
                var collapsedItemFrame = CGRect(origin: CGPoint(x: 0.0, y: floor((collapsedSize.height - collapsedEmojiSizes[mappedIndex].height) * 0.5)), size: collapsedEmojiSizes[mappedIndex])
                if i < 2 {
                    if mappedIndex != 0 {
                        collapsedEmojiLeftOffset += collapsedEmojiSpacing
                    }
                    collapsedItemFrame.origin.x = collapsedEmojiLeftOffset
                    collapsedEmojiLeftOffset += collapsedEmojiSizes[mappedIndex].width
                } else {
                    if mappedIndex != 0 {
                        collapsedEmojiRightOffset -= collapsedEmojiSpacing
                    }
                    collapsedItemFrame.origin.x = collapsedEmojiRightOffset - collapsedEmojiSizes[mappedIndex].width
                    collapsedEmojiRightOffset -= collapsedEmojiSizes[mappedIndex].width
                }
                
                var expandedItemFrame = CGRect(origin: CGPoint(x: floor((backgroundFrame.width - expandedEmojiWidth) * 0.5), y: expandedTopInset), size: emojiItemSizes[mappedIndex])
                expandedItemFrame.origin.x += CGFloat(mappedIndex) * (emojiItemSizes[0].width + expandedEmojiSpacing)
                
                let itemFrame: CGRect
                if component.isExpanded {
                    itemFrame = expandedItemFrame
                } else {
                    itemFrame = collapsedItemFrame
                }
                
                if let itemView = self.emojiItems[mappedIndex].view {
                    if itemView.superview == nil {
                        self.containerView.addSubview(itemView)
                    }
                    transition.setPosition(view: itemView, position: itemFrame.center)
                    itemView.bounds = CGRect(origin: CGPoint(), size: emojiItemSizes[mappedIndex])
                    transition.setScale(view: itemView, scale: itemFrame.height / emojiItemSizes[mappedIndex].height)
                }
            }
            
            var collapsedTextFrame = CGRect(origin: CGPoint(x: collapsedEmojiLeftOffset + collapsedEmojiTextSpacing, y: floor((collapsedSize.height - collapsedTextSize.height) * 0.5)), size: collapsedTextSize)
            var expandedTextFrame = CGRect(origin: CGPoint(x: floor((backgroundSize.width - expandedTextSize.width) * 0.5), y: expandedTopInset + emojiItemSizes[0].height + expandedEmojiTextSpacing), size: expandedTextSize)
            
            if component.isExpanded {
                collapsedTextFrame.origin = expandedTextFrame.origin
            } else {
                expandedTextFrame.origin = collapsedTextFrame.origin
            }
            
            if let collapsedTextView = self.collapsedText.view {
                if collapsedTextView.superview == nil {
                    collapsedTextView.layer.anchorPoint = CGPoint()
                    self.containerView.addSubview(collapsedTextView)
                } else {
                    if collapsedTextView.alpha != (component.isExpanded ? 0.0 : 1.0) {
                        if let blurFilter = CALayer.blur() {
                            let maxBlur: CGFloat = 8.0
                            if !component.isExpanded {
                                blurFilter.setValue(0.0 as NSNumber, forKey: "inputRadius")
                                collapsedTextView.layer.filters = [blurFilter]
                                collapsedTextView.layer.animate(from: maxBlur as NSNumber, to: 0.0 as NSNumber, keyPath: "filters.gaussianBlur.inputRadius", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2, removeOnCompletion: false, completion: { [weak collapsedTextView] flag in
                                    if flag, let collapsedTextView {
                                        collapsedTextView.layer.filters = nil
                                    }
                                })
                            } else {
                                blurFilter.setValue(maxBlur as NSNumber, forKey: "inputRadius")
                                collapsedTextView.layer.filters = [blurFilter]
                                collapsedTextView.layer.animate(from: 0.0 as NSNumber, to: maxBlur as NSNumber, keyPath: "filters.gaussianBlur.inputRadius", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2, removeOnCompletion: true)
                            }
                        }
                    }
                }
                transition.setPosition(view: collapsedTextView, position: collapsedTextFrame.origin)
                collapsedTextView.bounds = CGRect(origin: CGPoint(), size: collapsedTextFrame.size)
                alphaTransition.setAlpha(view: collapsedTextView, alpha: component.isExpanded ? 0.0 : 1.0)
            }
            
            if let expandedTextView = self.expandedText.view {
                if expandedTextView.superview == nil {
                    expandedTextView.layer.anchorPoint = CGPoint()
                    self.containerView.addSubview(expandedTextView)
                } else {
                    if expandedTextView.alpha != (component.isExpanded ? 1.0 : 0.0) {
                        if let blurFilter = CALayer.blur() {
                            let maxBlur: CGFloat = 8.0
                            if component.isExpanded {
                                blurFilter.setValue(0.0 as NSNumber, forKey: "inputRadius")
                                expandedTextView.layer.filters = [blurFilter]
                                expandedTextView.layer.animate(from: maxBlur as NSNumber, to: 0.0 as NSNumber, keyPath: "filters.gaussianBlur.inputRadius", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2, removeOnCompletion: false, completion: { [weak expandedTextView] flag in
                                    if flag, let expandedTextView {
                                        expandedTextView.layer.filters = nil
                                    }
                                })
                            } else {
                                blurFilter.setValue(maxBlur as NSNumber, forKey: "inputRadius")
                                expandedTextView.layer.filters = [blurFilter]
                                expandedTextView.layer.animate(from: 0.0 as NSNumber, to: maxBlur as NSNumber, keyPath: "filters.gaussianBlur.inputRadius", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2, removeOnCompletion: true)
                            }
                        }
                    }
                }
                transition.setPosition(view: expandedTextView, position: expandedTextFrame.origin)
                expandedTextView.bounds = CGRect(origin: CGPoint(), size: expandedTextFrame.size)
                alphaTransition.setAlpha(view: expandedTextView, alpha: component.isExpanded ? 1.0 : 0.0)
            }
            
            let expandedButtonOffset: CGFloat = component.isExpanded ? 0.0 : (expandedButtonBottomInset + expandedButtonTextSize.height + expandedButtonTopInset)
            
            if self.expandedSeparatorLayer.superlayer == nil {
                self.containerView.layer.addSublayer(self.expandedSeparatorLayer)
            }
            self.expandedSeparatorLayer.backgroundColor = component.theme.list.itemBlocksSeparatorColor.cgColor
            transition.setFrame(layer: self.expandedSeparatorLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: backgroundSize.height - expandedButtonBottomInset - expandedButtonTextSize.height - expandedButtonTopInset + expandedButtonOffset), size: CGSize(width: backgroundSize.width, height: UIScreenPixel)))
            alphaTransition.setAlpha(layer: self.expandedSeparatorLayer, alpha: component.isExpanded ? 1.0 : 0.0)
            
            if let expandedButtonTextView = self.expandedButtonText.view {
                if expandedButtonTextView.superview == nil {
                    self.containerView.addSubview(expandedButtonTextView)
                }
                transition.setFrame(view: expandedButtonTextView, frame: CGRect(origin: CGPoint(x: floor((backgroundSize.width - expandedButtonTextSize.width) * 0.5), y: backgroundSize.height - expandedButtonBottomInset - expandedButtonTextSize.height + expandedButtonOffset), size: expandedButtonTextSize))
                alphaTransition.setAlpha(view: expandedButtonTextView, alpha: component.isExpanded ? 1.0 : 0.0)
            }
            
            transition.setFrame(view: self.containerView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: backgroundSize))
            
            return CGSize(width: backgroundSize.width, height: collapsedSize.height)
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
