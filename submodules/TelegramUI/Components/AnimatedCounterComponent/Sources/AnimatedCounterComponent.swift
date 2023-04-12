import Foundation
import UIKit
import Display
import ComponentFlow

final class AnimatedCounterItemComponent: Component {
    public let font: UIFont
    public let color: UIColor
    public let text: String
    public let numericValue: Int
    public let alignment: CGFloat
    
    public init(
        font: UIFont,
        color: UIColor,
        text: String,
        numericValue: Int,
        alignment: CGFloat
    ) {
        self.font = font
        self.color = color
        self.text = text
        self.numericValue = numericValue
        self.alignment = alignment
    }

    public static func ==(lhs: AnimatedCounterItemComponent, rhs: AnimatedCounterItemComponent) -> Bool {
        if lhs.font != rhs.font {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.numericValue != rhs.numericValue {
            return false
        }
        if lhs.alignment != rhs.alignment {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let contentView: UIImageView
        
        private var component: AnimatedCounterItemComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.contentView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.contentView)
        }

        required init(coder: NSCoder) {
            preconditionFailure()
        }

        func update(component: AnimatedCounterItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let previousNumericValue = self.component?.numericValue
            
            self.component = component
            self.state = state
            
            let text = NSAttributedString(string: component.text, font: component.font, textColor: component.color)
            let textBounds = text.boundingRect(with: availableSize, options: [.usesLineFragmentOrigin], context: nil)
            let size = CGSize(width: ceil(textBounds.width), height: ceil(textBounds.height))
            
            let previousContentImage = self.contentView.image
            let previousContentFrame = self.contentView.frame
            
            self.contentView.image = generateImage(size, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                UIGraphicsPushContext(context)
                
                text.draw(at: textBounds.origin)
                
                UIGraphicsPopContext()
            })
            self.contentView.frame = CGRect(origin: CGPoint(), size: size)
            
            if !transition.animation.isImmediate, let previousContentImage, !previousContentFrame.isEmpty, let previousNumericValue, previousNumericValue != component.numericValue {
                let previousContentView = UIImageView()
                previousContentView.image = previousContentImage
                previousContentView.frame = CGRect(origin: CGPoint(x: size.width * component.alignment - previousContentFrame.width * component.alignment, y: previousContentFrame.minY), size: previousContentFrame.size)
                self.addSubview(previousContentView)
                
                let offsetY: CGFloat = size.height * 0.6 * (previousNumericValue < component.numericValue ? -1.0 : 1.0)
                
                let subTransition = Transition(animation: .curve(duration: 0.16, curve: .easeInOut))
                
                subTransition.animatePosition(view: self.contentView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                subTransition.animateAlpha(view: self.contentView, from: 0.0, to: 1.0)
                
                subTransition.setPosition(view: previousContentView, position: CGPoint(x: previousContentView.layer.position.x, y: previousContentView.layer.position.y - offsetY))
                subTransition.setAlpha(view: previousContentView, alpha: 0.0, completion: { [weak previousContentView] _ in
                    previousContentView?.removeFromSuperview()
                })
            }
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}


public final class AnimatedCounterComponent: Component {
    public enum Alignment {
        case left
        case right
    }
    
    public struct Item: Equatable {
        public var id: AnyHashable
        public var text: String
        public var numericValue: Int
        
        public init(id: AnyHashable, text: String, numericValue: Int) {
            self.id = id
            self.text = text
            self.numericValue = numericValue
        }
    }
    
    public let font: UIFont
    public let color: UIColor
    public let alignment: Alignment
    public let items: [Item]
    
    public init(
        font: UIFont,
        color: UIColor,
        alignment: Alignment,
        items: [Item]
    ) {
        self.font = font
        self.color = color
        self.alignment = alignment
        self.items = items
    }

    public static func ==(lhs: AnimatedCounterComponent, rhs: AnimatedCounterComponent) -> Bool {
        if lhs.font != rhs.font {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        if lhs.alignment != rhs.alignment {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        return true
    }

    private final class ItemView {
        let view = ComponentView<Empty>()
    }

    public final class View: UIView {
        private var itemViews: [AnyHashable: ItemView] = [:]
        
        private var component: AnimatedCounterComponent?
        private weak var state: EmptyComponentState?
        
        private var measuredSpaceWidth: CGFloat?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init(coder: NSCoder) {
            preconditionFailure()
        }

        func update(component: AnimatedCounterComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let spaceWidth: CGFloat
            if let measuredSpaceWidth = self.measuredSpaceWidth, let previousComponent = self.component, previousComponent.font.pointSize == component.font.pointSize {
                spaceWidth = measuredSpaceWidth
            } else {
                spaceWidth = ceil(NSAttributedString(string: " ", font: component.font, textColor: .black).boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil).width)
                self.measuredSpaceWidth = spaceWidth
            }
            
            self.component = component
            self.state = state
            
            var size = CGSize()
            
            var validIds: [AnyHashable] = []
            for item in component.items {
                if size.width != 0.0 {
                    size.width += spaceWidth
                }
                
                validIds.append(item.id)
                
                let itemView: ItemView
                var itemTransition = transition
                if let current = self.itemViews[item.id] {
                    itemView = current
                } else {
                    itemTransition = .immediate
                    itemView = ItemView()
                    self.itemViews[item.id] = itemView
                }
                
                let itemSize = itemView.view.update(
                    transition: itemTransition,
                    component: AnyComponent(AnimatedCounterItemComponent(
                        font: component.font,
                        color: component.color,
                        text: item.text,
                        numericValue: item.numericValue,
                        alignment: component.alignment == .left ? 0.0 : 1.0
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                
                if let itemComponentView = itemView.view.view {
                    if itemComponentView.superview == nil {
                        self.addSubview(itemComponentView)
                    }
                    let itemFrame = CGRect(origin: CGPoint(x: size.width, y: 0.0), size: itemSize)
                    switch component.alignment {
                    case .left:
                        itemComponentView.layer.anchorPoint = CGPoint(x: 0.0, y: 0.5)
                        itemTransition.setPosition(view: itemComponentView, position: CGPoint(x: itemFrame.minX, y: itemFrame.midY))
                    case .right:
                        itemComponentView.layer.anchorPoint = CGPoint(x: 1.0, y: 0.5)
                        itemTransition.setPosition(view: itemComponentView, position: CGPoint(x: itemFrame.maxX, y: itemFrame.midY))
                    }
                    itemComponentView.bounds = CGRect(origin: CGPoint(), size: itemFrame.size)
                }
                
                size.width += itemSize.width
                size.height = max(size.height, itemSize.height)
            }
            
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let componentView = itemView.view.view {
                        transition.setAlpha(view: componentView, alpha: 0.0, completion: { [weak componentView] _ in
                            componentView?.removeFromSuperview()
                        })
                    }
                }
            }
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
