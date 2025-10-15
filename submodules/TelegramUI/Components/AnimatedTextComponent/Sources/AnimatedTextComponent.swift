import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import BundleIconComponent

extension ComponentTransition {
    func animateBlur(layer: CALayer, from: CGFloat, to: CGFloat, delay: Double = 0.0, removeOnCompletion: Bool = true, completion: ((Bool) -> Void)? = nil) {
        if let blurFilter = CALayer.blur() {
            blurFilter.setValue(to as NSNumber, forKey: "inputRadius")
            layer.filters = [blurFilter]
            layer.animate(from: from as NSNumber, to: to as NSNumber, keyPath: "filters.gaussianBlur.inputRadius", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.3, delay: delay, removeOnCompletion: removeOnCompletion, completion: { [weak layer] _ in
                guard let layer else {
                    return
                }
                if to == 0.0 && removeOnCompletion {
                    layer.filters = nil
                }
            })
        }
    }
}

public final class AnimatedTextComponent: Component {
    public struct Item: Equatable {
        public enum Content: Equatable {
            case text(String)
            case number(Int, minDigits: Int)
            case icon(String, offset: CGPoint)
        }
        
        public var id: AnyHashable
        public var isUnbreakable: Bool
        public var content: Content
        
        public init(id: AnyHashable, isUnbreakable: Bool = false, content: Content) {
            self.id = id
            self.isUnbreakable = isUnbreakable
            self.content = content
        }
    }
    
    public let font: UIFont
    public let color: UIColor
    public let items: [Item]
    public let noDelay: Bool
    public let animateScale: Bool
    public let preferredDirectionIsDown: Bool
    public let blur: Bool
    
    public init(
        font: UIFont,
        color: UIColor,
        items: [Item],
        noDelay: Bool = false,
        animateScale: Bool = true,
        preferredDirectionIsDown: Bool = false,
        blur: Bool = false
    ) {
        self.font = font
        self.color = color
        self.items = items
        self.noDelay = noDelay
        self.animateScale = animateScale
        self.preferredDirectionIsDown = preferredDirectionIsDown
        self.blur = blur
    }

    public static func ==(lhs: AnimatedTextComponent, rhs: AnimatedTextComponent) -> Bool {
        if lhs.font != rhs.font {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.noDelay != rhs.noDelay {
            return false
        }
        if lhs.animateScale != rhs.animateScale {
            return false
        }
        if lhs.preferredDirectionIsDown != rhs.preferredDirectionIsDown {
            return false
        }
        if lhs.blur != rhs.blur {
            return false
        }
        return true
    }
    
    private struct CharacterKey: Hashable {
        var itemId: AnyHashable
        var index: Int
        var value: String
    }

    public final class View: UIView {
        private var characters: [CharacterKey: ComponentView<Empty>] = [:]
        
        private var component: AnimatedTextComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init(coder: NSCoder) {
            preconditionFailure()
        }

        func update(component: AnimatedTextComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            var size = CGSize()
            
            let delayNorm: CGFloat = 0.002
            var offsetNorm: CGFloat = 0.4
            let transitionBlurRadius: CGFloat = 6.0
            
            var firstDelayWidth: CGFloat?
            if component.preferredDirectionIsDown {
                firstDelayWidth = 0.0
                offsetNorm = 0.8
            }
            
            var validKeys: [CharacterKey] = []
            for item in component.items {
                var itemText: [String] = []
                switch item.content {
                case let .text(text):
                    if item.isUnbreakable {
                        itemText = [text]
                    } else {
                        itemText = text.map(String.init)
                    }
                case let .number(value, minDigits):
                    var valueText: String = "\(value)"
                    while valueText.count < minDigits {
                        valueText.insert("0", at: valueText.startIndex)
                    }
                    
                    if item.isUnbreakable {
                        itemText = [valueText]
                    } else {
                        itemText = valueText.map(String.init)
                    }
                case let .icon(iconName, _):
                    let characterKey = CharacterKey(itemId: item.id, index: 0, value: iconName)
                    validKeys.append(characterKey)
                }
                var index = 0
                for character in itemText {
                    let characterKey = CharacterKey(itemId: item.id, index: index, value: character)
                    index += 1
                    
                    validKeys.append(characterKey)
                }
            }
            
            var outLastDelayWidth: CGFloat?
            var outFirstDelayWidth: CGFloat?
            if component.preferredDirectionIsDown {
                for (key, characterView) in self.characters {
                    if !validKeys.contains(key), let characterView = characterView.view {
                        if let outFirstDelayWidthValue = outFirstDelayWidth {
                            outFirstDelayWidth = max(outFirstDelayWidthValue, characterView.frame.center.x)
                        } else {
                            outFirstDelayWidth = characterView.frame.center.x
                        }
                        
                        if let outLastDelayWidthValue = outLastDelayWidth {
                            outLastDelayWidth = min(outLastDelayWidthValue, characterView.frame.center.x)
                        } else {
                            outLastDelayWidth = characterView.frame.center.x
                        }
                    }
                }
            }
            if outLastDelayWidth != nil {
                firstDelayWidth = outLastDelayWidth
            }
            
            for item in component.items {
                enum AnimatedTextCharacter {
                    case text(String)
                    case icon(String, CGPoint)
                    
                    var value: String {
                        switch self {
                        case let .text(value), let .icon(value, _):
                            return value
                        }
                    }
                }
                var itemText: [AnimatedTextCharacter] = []
                switch item.content {
                case let .text(text):
                    if item.isUnbreakable {
                        itemText = [.text(text)]
                    } else {
                        itemText = text.map { .text(String($0)) }
                    }
                case let .number(value, minDigits):
                    var valueText: String = "\(value)"
                    while valueText.count < minDigits {
                        valueText.insert("0", at: valueText.startIndex)
                    }
                    
                    if item.isUnbreakable {
                        itemText = [.text(valueText)]
                    } else {
                        itemText = valueText.map { .text(String($0)) }
                    }
                case let .icon(iconName, offset):
                    itemText = [.icon(iconName, offset)]
                }
                var index = 0
                for character in itemText {
                    let characterKey = CharacterKey(itemId: item.id, index: index, value: character.value)
                    index += 1
                    
                    var characterTransition = transition
                    let characterView: ComponentView<Empty>
                    if let current = self.characters[characterKey] {
                        characterView = current
                    } else {
                        characterTransition = .immediate
                        characterView = ComponentView()
                        self.characters[characterKey] = characterView
                    }
                    
                    let characterComponent: AnyComponent<Empty>
                    var characterOffset: CGPoint = .zero
                    switch character {
                    case let .text(text):
                        characterComponent = AnyComponent(Text(
                            text: String(text),
                            font: component.font,
                            color: component.color
                        ))
                    case let .icon(iconName, offset):
                        characterComponent = AnyComponent(BundleIconComponent(
                            name: iconName,
                            tintColor: component.color
                        ))
                        characterOffset = offset
                    }
                    
                    let characterSize = characterView.update(
                        transition: characterTransition,
                        component: characterComponent,
                        environment: {},
                        containerSize: CGSize(width: availableSize.width, height: 100.0)
                    )
                    let characterFrame = CGRect(origin: CGPoint(x: size.width + characterOffset.x, y: characterOffset.y), size: characterSize)
                    if let characterComponentView = characterView.view {
                        var animateIn = false
                        if characterComponentView.superview == nil {
                            characterComponentView.layer.rasterizationScale = UIScreenScale
                            self.addSubview(characterComponentView)
                            animateIn = true
                        }
                        
                        if characterComponentView.frame != characterFrame {
                            if characterTransition.animation.isImmediate {
                                characterComponentView.frame = characterFrame
                            } else {
                                var delayWidth: Double = 0.0
                                if let firstDelayWidth {
                                    if characterFrame.midX > characterComponentView.frame.midX {
                                        delayWidth = 0.0
                                    } else {
                                        delayWidth = abs(size.width - firstDelayWidth)
                                    }
                                } else {
                                    firstDelayWidth = size.width
                                }
                                
                                characterComponentView.bounds = CGRect(origin: CGPoint(), size: characterFrame.size)
                                let deltaPosition = CGPoint(x: characterFrame.midX - characterComponentView.frame.midX, y: characterFrame.midY - characterComponentView.frame.midY)
                                characterComponentView.center = characterFrame.center
                                characterComponentView.layer.animatePosition(from: CGPoint(x: -deltaPosition.x, y: -deltaPosition.y), to: CGPoint(), duration: 0.4, delay: delayNorm * delayWidth, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                            }
                        }
                        characterTransition.setFrame(view: characterComponentView, frame: characterFrame)
                        
                        if animateIn, !transition.animation.isImmediate {
                            var delayWidth: Double = 0.0
                            if !component.noDelay || component.preferredDirectionIsDown {
                                if let firstDelayWidth {
                                    delayWidth = size.width - firstDelayWidth
                                } else {
                                    firstDelayWidth = size.width
                                }
                            }
                            
                            if component.animateScale {
                                characterComponentView.layer.animateScale(from: 0.001, to: 1.0, duration: 0.4, delay: delayNorm * delayWidth, timingFunction: kCAMediaTimingFunctionSpring)
                            }
                            if component.blur {
                                ComponentTransition.easeInOut(duration: 0.2).animateBlur(layer: characterComponentView.layer, from: transitionBlurRadius, to: 0.0, delay: delayNorm * delayWidth)
                            }
                            characterComponentView.layer.animatePosition(from: CGPoint(x: 0.0, y: characterSize.height * offsetNorm), to: CGPoint(), duration: 0.4, delay: delayNorm * delayWidth, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                            characterComponentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18, delay: delayNorm * delayWidth)
                        }
                    }
                    
                    size.height = max(size.height, characterSize.height)
                    size.width += max(0.0, characterSize.width - UIScreenPixel * 2.0)
                }
            }
            
            let outScaleTransition: ComponentTransition = .spring(duration: 0.4)
            let outAlphaTransition: ComponentTransition = .easeInOut(duration: 0.18)
            
            var removedKeys: [CharacterKey] = []
            for (key, characterView) in self.characters {
                if !validKeys.contains(key) {
                    removedKeys.append(key)
                    
                    if let characterComponentView = characterView.view {
                        if !transition.animation.isImmediate {
                            var delayWidth: Double = 0.0
                            if let outFirstDelayWidth {
                                delayWidth = abs(characterComponentView.frame.midX - outFirstDelayWidth)
                            } else {
                                outFirstDelayWidth = characterComponentView.frame.midX
                            }
                            delayWidth = max(0.0, delayWidth)
                            
                            if component.animateScale {
                                outScaleTransition.setScale(view: characterComponentView, scale: 0.01, delay: delayNorm * delayWidth)
                            }
                            let targetY: CGFloat
                            if component.preferredDirectionIsDown {
                                targetY = characterComponentView.center.y - characterComponentView.bounds.height * offsetNorm
                            } else {
                                targetY = characterComponentView.center.y - characterComponentView.bounds.height * offsetNorm
                            }
                            outScaleTransition.setPosition(view: characterComponentView, position: CGPoint(x: characterComponentView.center.x, y: targetY), delay: delayNorm * delayWidth)
                            outAlphaTransition.setAlpha(view: characterComponentView, alpha: 0.0, delay: delayNorm * delayWidth, completion: { [weak characterComponentView] _ in
                                characterComponentView?.removeFromSuperview()
                            })
                            if component.blur {
                                outAlphaTransition.animateBlur(layer: characterComponentView.layer, from: 0.0, to: transitionBlurRadius, delay: delayNorm * delayWidth, removeOnCompletion: false)
                            }
                        } else {
                            characterComponentView.removeFromSuperview()
                        }
                    }
                }
            }
            for removedKey in removedKeys {
                self.characters.removeValue(forKey: removedKey)
            }
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public extension AnimatedTextComponent {
    static func extractAnimatedTextString(string: PresentationStrings.FormattedString, id: String, mapping: [Int: AnimatedTextComponent.Item.Content]) -> [AnimatedTextComponent.Item] {
        var textItems: [AnimatedTextComponent.Item] = []
        
        var previousIndex = 0
        let nsString = string.string as NSString
        for range in string.ranges.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
            if range.range.lowerBound > previousIndex {
                textItems.append(AnimatedTextComponent.Item(id: AnyHashable("\(id)_text_before_\(range.index)"), isUnbreakable: true, content: .text(nsString.substring(with: NSRange(location: previousIndex, length: range.range.lowerBound - previousIndex)))))
            }
            if let value = mapping[range.index] {
                let isUnbreakable: Bool
                switch value {
                case .text:
                    isUnbreakable = true
                case .number:
                    isUnbreakable = false
                case .icon:
                    isUnbreakable = true
                }
                textItems.append(AnimatedTextComponent.Item(id: AnyHashable("\(id)_item_\(range.index)"), isUnbreakable: isUnbreakable, content: value))
            }
            previousIndex = range.range.upperBound
        }
        if nsString.length > previousIndex {
            textItems.append(AnimatedTextComponent.Item(id: AnyHashable("\(id)_text_end"), isUnbreakable: true, content: .text(nsString.substring(with: NSRange(location: previousIndex, length: nsString.length - previousIndex)))))
        }
        
        return textItems
    }
}
