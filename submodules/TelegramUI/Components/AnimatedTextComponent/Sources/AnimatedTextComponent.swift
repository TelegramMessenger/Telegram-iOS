import Foundation
import UIKit
import Display
import ComponentFlow

public final class AnimatedTextComponent: Component {
    public struct Item: Equatable {
        public enum Content: Equatable {
            case text(String)
            case number(Int, minDigits: Int)
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
    
    public init(
        font: UIFont,
        color: UIColor,
        items: [Item]
    ) {
        self.font = font
        self.color = color
        self.items = items
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
            
            var firstDelayWidth: CGFloat?
            
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
                }
                var index = 0
                for character in itemText {
                    let characterKey = CharacterKey(itemId: item.id, index: index, value: character)
                    index += 1
                    
                    validKeys.append(characterKey)
                    
                    var characterTransition = transition
                    let characterView: ComponentView<Empty>
                    if let current = self.characters[characterKey] {
                        characterView = current
                    } else {
                        characterTransition = .immediate
                        characterView = ComponentView()
                        self.characters[characterKey] = characterView
                    }
                    
                    let characterSize = characterView.update(
                        transition: characterTransition,
                        component: AnyComponent(Text(
                            text: String(character),
                            font: component.font,
                            color: component.color
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width, height: 100.0)
                    )
                    let characterFrame = CGRect(origin: CGPoint(x: size.width, y: 0.0), size: characterSize)
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
                                    delayWidth = size.width - firstDelayWidth
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
                            if let firstDelayWidth {
                                delayWidth = size.width - firstDelayWidth
                            } else {
                                firstDelayWidth = size.width
                            }
                            
                            characterComponentView.layer.animateScale(from: 0.001, to: 1.0, duration: 0.4, delay: delayNorm * delayWidth, timingFunction: kCAMediaTimingFunctionSpring)
                            characterComponentView.layer.animatePosition(from: CGPoint(x: 0.0, y: characterSize.height * 0.5), to: CGPoint(), duration: 0.4, delay: delayNorm * delayWidth, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                            characterComponentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18, delay: delayNorm * delayWidth)
                        }
                    }
                    
                    size.height = max(size.height, characterSize.height)
                    size.width += max(0.0, characterSize.width - UIScreenPixel * 2.0)
                }
            }
            
            let outScaleTransition: ComponentTransition = .spring(duration: 0.4)
            let outAlphaTransition: ComponentTransition = .easeInOut(duration: 0.18)
            
            var outFirstDelayWidth: CGFloat?
            
            var removedKeys: [CharacterKey] = []
            for (key, characterView) in self.characters {
                if !validKeys.contains(key) {
                    removedKeys.append(key)
                    
                    if let characterComponentView = characterView.view {
                        if !transition.animation.isImmediate {
                            var delayWidth: Double = 0.0
                            if let outFirstDelayWidth {
                                delayWidth = characterComponentView.frame.minX - outFirstDelayWidth
                            } else {
                                outFirstDelayWidth = characterComponentView.frame.minX
                            }
                            
                            outScaleTransition.setScale(view: characterComponentView, scale: 0.01, delay: delayNorm * delayWidth)
                            outScaleTransition.setPosition(view: characterComponentView, position: CGPoint(x: characterComponentView.center.x, y: characterComponentView.center.y - characterComponentView.bounds.height * 0.4), delay: delayNorm * delayWidth)
                            outAlphaTransition.setAlpha(view: characterComponentView, alpha: 0.0, delay: delayNorm * delayWidth, completion: { [weak characterComponentView] _ in
                                characterComponentView?.removeFromSuperview()
                            })
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
