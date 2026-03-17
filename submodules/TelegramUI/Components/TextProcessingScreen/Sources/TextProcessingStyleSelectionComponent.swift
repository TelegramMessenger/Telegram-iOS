import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import MultilineTextComponent
import TelegramCore

final class TextProcessingStyleSelectionComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let selectedStyle: TelegramComposeAIMessageMode.Style
    let updateStyle: (TelegramComposeAIMessageMode.Style) -> Void

    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        selectedStyle: TelegramComposeAIMessageMode.Style,
        updateStyle: @escaping (TelegramComposeAIMessageMode.Style) -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.selectedStyle = selectedStyle
        self.updateStyle = updateStyle
    }

    static func ==(lhs: TextProcessingStyleSelectionComponent, rhs: TextProcessingStyleSelectionComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.selectedStyle != rhs.selectedStyle {
            return false
        }
        return true
    }

    final class View: UIView {
        private var component: TextProcessingStyleSelectionComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false

        private var itemViews: [TelegramComposeAIMessageMode.Style: ComponentView<Empty>] = [:]
        private let selectedBackgroundView: UIImageView
        
        override init(frame: CGRect) {
            self.selectedBackgroundView = UIImageView()
            self.selectedBackgroundView.isHidden = true
            self.selectedBackgroundView.alpha = 0.0
            
            super.init(frame: frame)
            
            self.addSubview(self.selectedBackgroundView)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }

        @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = recognizer.state {
                for (id, itemView) in self.itemViews {
                    if let itemComponentView = itemView.view {
                        if itemComponentView.bounds.contains(self.convert(recognizer.location(in: self), to: itemComponentView)) {
                            component.updateStyle(id)
                            break
                        }
                    }
                }
            }
        }
        
        func update(component: TextProcessingStyleSelectionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            
            self.component = component
            self.state = state
            
            var styleData: [(id: TelegramComposeAIMessageMode.Style, icon: String, title: String)] = []
            styleData.append((.neutral, "🏳️", "Neutral"))
            styleData.append((.formal, "🤝", "Formal"))
            styleData.append((.short, "🎯", "Short"))
            styleData.append((.savage, "🍖", "Savage"))
            styleData.append((.biblical, "🕯", "Biblical"))
            styleData.append((.posh, "🍷", "Posh"))
            
            let itemSize = CGSize(width: floor(availableSize.width / CGFloat(styleData.count)), height: availableSize.height)
            var selectedItemFrame: CGRect?
            for i in 0 ..< styleData.count {
                let style = styleData[i]
                let itemView: ComponentView<Empty>
                var itemTransition = transition
                if let current = self.itemViews[style.id] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = ComponentView()
                    self.itemViews[style.id] = itemView
                }
                let itemFrame = CGRect(origin: CGPoint(x: CGFloat(i) * itemSize.width, y: 0.0), size: itemSize)
                let _ = itemView.update(
                    transition: itemTransition,
                    component: AnyComponent(ItemComponent(
                        theme: component.theme,
                        icon: style.icon,
                        title: style.title
                    )),
                    environment: {},
                    containerSize: itemSize
                )
                if let itemComponentView = itemView.view {
                    if itemComponentView.superview == nil {
                        self.addSubview(itemComponentView)
                    }
                    itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                }
                if style.id == component.selectedStyle {
                    selectedItemFrame = CGRect(origin: CGPoint(x: itemFrame.minX, y: itemFrame.minY - 5.0), size: CGSize(width: itemFrame.width, height: itemFrame.height + 5.0 + 3.0))
                }
            }
            
            if self.selectedBackgroundView.image == nil {
                self.selectedBackgroundView.image = generateStretchableFilledCircleImage(diameter: 16.0 * 2.0, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            self.selectedBackgroundView.tintColor = component.theme.list.itemHighlightedBackgroundColor.withMultipliedAlpha(0.6)
            
            if let selectedItemFrame {
                var selectedBackgroundTransition = transition
                if self.selectedBackgroundView.isHidden {
                    self.selectedBackgroundView.isHidden = false
                    selectedBackgroundTransition = selectedBackgroundTransition.withAnimation(.none)
                }
                selectedBackgroundTransition.setFrame(view: self.selectedBackgroundView, frame: selectedItemFrame)
                alphaTransition.setAlpha(view: self.selectedBackgroundView, alpha: 1.0)
            } else {
                if !self.selectedBackgroundView.isHidden {
                    alphaTransition.setAlpha(view: self.selectedBackgroundView, alpha: 0.0, completion: { [weak self] flag in
                        guard let self, flag else {
                            return
                        }
                        self.selectedBackgroundView.isHidden = true
                    })
                }
            }
            
            return CGSize(width: availableSize.width, height: availableSize.height)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ItemComponent: Component {
    let theme: PresentationTheme
    let icon: String
    let title: String
    
    init(
        theme: PresentationTheme,
        icon: String,
        title: String
    ) {
        self.theme = theme
        self.icon = icon
        self.title = title
    }
    
    static func ==(lhs: ItemComponent, rhs: ItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var imageIcon: ComponentView<Empty>?
        private let title = ComponentView<Empty>()
        
        private var component: ItemComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state

            let iconTintColor = component.theme.list.itemPrimaryTextColor

            let imageIcon: ComponentView<Empty>
            var iconTransition = transition
            if let current = self.imageIcon {
                imageIcon = current
            } else {
                iconTransition = iconTransition.withAnimation(.none)
                imageIcon = ComponentView()
                self.imageIcon = imageIcon
            }

            let iconSize = imageIcon.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.icon, font: Font.regular(25.0), textColor: .black))
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: -1.0), size: iconSize)
            if let imageIconView = imageIcon.view {
                if imageIconView.superview == nil {
                    self.addSubview(imageIconView)
                }
                iconTransition.setFrame(view: imageIconView, frame: iconFrame)
            }

            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.semibold(10.0), textColor: iconTintColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: availableSize.height - 5.0 - titleSize.height), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }

            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
