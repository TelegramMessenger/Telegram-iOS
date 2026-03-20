import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import MultilineTextComponent
import TelegramCore

func localizedStyleName(strings: PresentationStrings, styleId: TelegramComposeAIMessageMode.StyleId) -> String {
    switch styleId {
    case .neutral:
        return strings.TextProcessingStyle_Neutral
    case let .style(name):
        if let value = strings.primaryComponent.dict["TextProcessingStyle_\(name)"] {
            return value
        } else {
            return name.capitalized
        }
    }
}

final class TextProcessingStyleSelectionComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let styles: [TelegramComposeAIMessageMode.Style]
    let selectedStyle: TelegramComposeAIMessageMode.StyleId
    let updateStyle: (TelegramComposeAIMessageMode.StyleId) -> Void

    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        styles: [TelegramComposeAIMessageMode.Style],
        selectedStyle: TelegramComposeAIMessageMode.StyleId,
        updateStyle: @escaping (TelegramComposeAIMessageMode.StyleId) -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.styles = styles
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
        if lhs.styles != rhs.styles {
            return false
        }
        if lhs.selectedStyle != rhs.selectedStyle {
            return false
        }
        return true
    }

    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }

    final class View: UIView {
        private var component: TextProcessingStyleSelectionComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false

        private let scrollView: ScrollView
        private var itemViews: [TelegramComposeAIMessageMode.StyleId: ComponentView<Empty>] = [:]
        private let selectedBackgroundView: UIImageView

        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            self.selectedBackgroundView = UIImageView()
            self.selectedBackgroundView.isHidden = true
            self.selectedBackgroundView.alpha = 0.0

            super.init(frame: frame)

            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = false
            self.scrollView.scrollsToTop = false
            self.scrollView.clipsToBounds = false
            self.addSubview(self.scrollView)

            self.scrollView.addSubview(self.selectedBackgroundView)

            self.scrollView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
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
                        if itemComponentView.bounds.contains(self.scrollView.convert(recognizer.location(in: self.scrollView), to: itemComponentView)) {
                            if component.selectedStyle == id {
                                component.updateStyle(.neutral)
                            } else {
                                component.updateStyle(id)
                            }
                            self.scrollView.scrollRectToVisible(itemComponentView.frame.insetBy(dx: -100.0, dy: 0.0), animated: true)
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
            
            var styleData: [(id: TelegramComposeAIMessageMode.StyleId, icon: String, title: String)] = []
            for item in component.styles {
                styleData.append((item.id, item.emoji, localizedStyleName(strings: component.strings, styleId: item.id)))
            }
            
            let minSlotWidth: CGFloat = max(50.0, floor(availableSize.width / 5.0))
            let slotWidth = max(minSlotWidth, floor(availableSize.width / CGFloat(styleData.count)))
            let contentWidth = slotWidth * CGFloat(styleData.count)
            let itemSize = CGSize(width: slotWidth, height: availableSize.height)

            self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            self.scrollView.contentSize = CGSize(width: contentWidth, height: availableSize.height)
            self.scrollView.alwaysBounceHorizontal = contentWidth > availableSize.width

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
                let itemFrame = CGRect(origin: CGPoint(x: CGFloat(i) * slotWidth, y: 0.0), size: itemSize)
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
                        self.scrollView.addSubview(itemComponentView)
                    }
                    itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                }
                if style.id == component.selectedStyle {
                    selectedItemFrame = CGRect(origin: CGPoint(x: itemFrame.minX, y: itemFrame.minY - 5.0), size: CGSize(width: itemFrame.width, height: itemFrame.height + 5.0 + 3.0))
                }
            }

            var removedIds: [TelegramComposeAIMessageMode.StyleId] = []
            for (id, itemView) in self.itemViews {
                if !styleData.contains(where: { $0.id == id }) {
                    removedIds.append(id)
                    itemView.view?.removeFromSuperview()
                }
            }
            for id in removedIds {
                self.itemViews.removeValue(forKey: id)
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
