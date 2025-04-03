import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import BalancedTextComponent
import TelegramPresentationData
import CallsEmoji

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
        private let measureEmojiView = ComponentView<Empty>()
        private var pendingContainerView: UIView?
        private var pendingEmojiViews: [ComponentView<Empty>] = []
        private var emojiView: ComponentView<Empty>?

        private var component: EmojiItemComponent?
        private weak var state: EmptyComponentState?
        
        private var pendingEmojiValues: [String]?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
        }

        func update(component: EmojiItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
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
            
            let borderEmoji = 2
            let numEmoji = borderEmoji * 2 + 3

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
                let emojiFrame = CGRect(origin: CGPoint(x: floor((size.width - emojiSize.width) * 0.5), y: floor((size.height - emojiSize.height) * 0.5)), size: emojiSize)
                if let emojiComponentView = emojiView.view {
                    if emojiComponentView.superview == nil {
                        self.addSubview(emojiComponentView)
                    }
                    emojiViewTransition.setFrame(view: emojiComponentView, frame: emojiFrame)
                }
                
                self.pendingEmojiValues = nil
            } else {
                if let emojiView = self.emojiView {
                    self.emojiView = nil
                    emojiView.view?.removeFromSuperview()
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
                let pendingContainerView: UIView
                if let current = self.pendingContainerView {
                    pendingContainerView = current
                } else {
                    pendingContainerView = UIView()
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
                            pendingContainerView.addSubview(pendingEmojiComponentView)
                        }
                        pendingEmojiComponentView.frame = CGRect(origin: CGPoint(x: 0.0, y: CGFloat(i) * size.height), size: pendingEmojiViewSize)
                    }
                }

                pendingContainerView.frame = CGRect(origin: CGPoint(), size: size)

                if pendingContainerView.superview == nil {
                    self.addSubview(pendingContainerView)

                    let animation = CABasicAnimation(keyPath: "sublayerTransform.translation.y")
                    //animation.duration = 4.2
                    animation.duration = 0.2
                    animation.fromValue = -CGFloat(numEmoji - borderEmoji) * size.height
                    animation.toValue = CGFloat(borderEmoji - 3) * size.height
                    animation.timingFunction = CAMediaTimingFunction(name: .linear)
                    animation.autoreverses = false
                    animation.repeatCount = .infinity
                    
                    pendingContainerView.layer.add(animation, forKey: "offsetCycle")
                }
            } else if let pendingContainerView = self.pendingContainerView {
                self.pendingContainerView = nil
                pendingContainerView.removeFromSuperview()

                for emojiView in self.pendingEmojiViews {
                    emojiView.view?.removeFromSuperview()
                }
                self.pendingEmojiViews.removeAll()
            }
            
            //self.layer.borderColor = UIColor.red.cgColor
            //self.layer.borderWidth = 4.0

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
        private var isUpdating: Bool = false
        
        private var tapRecognizer: TapLongTapOrDoubleTapGestureRecognizer?
        
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
            
            self.component = component
            
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
                        emoji: i < component.emoji.count ? component.emoji[i] : nil
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
