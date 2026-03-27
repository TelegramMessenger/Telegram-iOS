import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import MultilineTextComponent
import TelegramCore
import EmojiStatusComponent
import AccountContext

final class TextProcessingStyleSelectionComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let styles: [TextProcessingScreen.Style]
    let selectedStyle: TelegramComposeAIMessageMode.StyleId
    let updateStyle: (TelegramComposeAIMessageMode.StyleId) -> Void

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        styles: [TextProcessingScreen.Style],
        selectedStyle: TelegramComposeAIMessageMode.StyleId,
        updateStyle: @escaping (TelegramComposeAIMessageMode.StyleId) -> Void
    ) {
        self.context = context
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
            
            let maxItemWidth: CGFloat = 80.0
            let itemPadding: CGFloat = 0.0
            let minSlotWidth: CGFloat = 50.0
            let maxSlotWidth: CGFloat = 80.0

            // First pass: measure all items to find intrinsic sizes
            var itemSizes: [TelegramComposeAIMessageMode.StyleId: CGSize] = [:]
            for i in 0 ..< component.styles.count {
                let style = component.styles[i]
                let itemView: ComponentView<Empty>
                var itemTransition = transition
                if let current = self.itemViews[style.id] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = ComponentView()
                    self.itemViews[style.id] = itemView
                }
                let measuredSize = itemView.update(
                    transition: itemTransition,
                    component: AnyComponent(ItemComponent(
                        context: component.context,
                        theme: component.theme,
                        iconFileId: style.emojiFileId,
                        iconFile: style.emojiFile,
                        title: style.title
                    )),
                    environment: {},
                    containerSize: CGSize(width: maxItemWidth, height: availableSize.height)
                )
                itemSizes[style.id] = measuredSize
            }

            // Compute uniform slot width from largest item
            var largestItemWidth: CGFloat = 0.0
            for (_, size) in itemSizes {
                largestItemWidth = max(largestItemWidth, size.width)
            }
            let contentBasedWidth = min(maxSlotWidth, max(minSlotWidth, largestItemWidth + itemPadding))
            let slotWidth: CGFloat
            if CGFloat(component.styles.count) * contentBasedWidth <= availableSize.width {
                slotWidth = floor(availableSize.width / CGFloat(component.styles.count))
            } else {
                var resolved: CGFloat = contentBasedWidth
                var targetVisible: CGFloat = min(7.5, floor((availableSize.width + 16.0) / (contentBasedWidth + 10.0)) + 0.5)
                while targetVisible >= 1.5 {
                    let candidateWidth = floor((availableSize.width + 16.0) / targetVisible)
                    if candidateWidth >= contentBasedWidth {
                        resolved = candidateWidth
                        break
                    }
                    targetVisible -= 1.0
                }
                slotWidth = resolved
            }
            let contentWidth = slotWidth * CGFloat(component.styles.count)

            self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            self.scrollView.contentSize = CGSize(width: contentWidth, height: availableSize.height)
            self.scrollView.alwaysBounceHorizontal = contentWidth > availableSize.width

            // Second pass: position items centered in their slots
            var selectedItemFrame: CGRect?
            for i in 0 ..< component.styles.count {
                let style = component.styles[i]
                guard let itemView = self.itemViews[style.id],
                      let naturalSize = itemSizes[style.id] else {
                    continue
                }
                let slotOriginX = CGFloat(i) * slotWidth
                let itemX = slotOriginX + floor((slotWidth - naturalSize.width) * 0.5)
                let itemFrame = CGRect(origin: CGPoint(x: itemX, y: 0.0), size: naturalSize)
                if let itemComponentView = itemView.view {
                    if itemComponentView.superview == nil {
                        self.scrollView.addSubview(itemComponentView)
                    }
                    transition.setFrame(view: itemComponentView, frame: itemFrame)
                }
                if style.id == component.selectedStyle {
                    selectedItemFrame = CGRect(origin: CGPoint(x: slotOriginX, y: -5.0), size: CGSize(width: slotWidth, height: availableSize.height + 5.0 + 3.0))
                }
            }

            var removedIds: [TelegramComposeAIMessageMode.StyleId] = []
            for (id, itemView) in self.itemViews {
                if !component.styles.contains(where: { $0.id == id }) {
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
    let context: AccountContext
    let theme: PresentationTheme
    let iconFileId: Int64?
    let iconFile: TelegramMediaFile?
    let title: String
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        iconFileId: Int64?,
        iconFile: TelegramMediaFile?,
        title: String
    ) {
        self.context = context
        self.theme = theme
        self.iconFileId = iconFileId
        self.iconFile = iconFile
        self.title = title
    }
    
    static func ==(lhs: ItemComponent, rhs: ItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.iconFileId != rhs.iconFileId {
            return false
        }
        if lhs.iconFile?.fileId != rhs.iconFile?.fileId {
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
            let previousComponent = self.component
            self.component = component
            self.state = state

            let iconTintColor = component.theme.list.itemPrimaryTextColor
            
            if previousComponent?.iconFileId != component.iconFileId {
                if let imageIcon = self.imageIcon {
                    self.imageIcon = nil
                    imageIcon.view?.removeFromSuperview()
                }
            }

            let imageIcon: ComponentView<Empty>
            var iconTransition = transition
            if let current = self.imageIcon {
                imageIcon = current
            } else {
                iconTransition = iconTransition.withAnimation(.none)
                imageIcon = ComponentView()
                self.imageIcon = imageIcon
            }
            
            let iconComponent: AnyComponent<Empty>
            if let iconFileId = component.iconFileId {
                let iconSize = CGSize(width: 34.0, height: 34.0)
                let content: EmojiStatusComponent.AnimationContent
                if let file = component.iconFile {
                    content = .file(file: file)
                } else {
                    content = .customEmoji(fileId: iconFileId)
                }
                iconComponent = AnyComponent(EmojiStatusComponent(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    content: .animation(
                        content: content,
                        size: iconSize,
                        placeholderColor: component.theme.list.mediaPlaceholderColor,
                        themeColor: component.theme.list.itemAccentColor,
                        loopMode: .count(0)
                    ),
                    size: iconSize,
                    isVisibleForAnimations: true,
                    action: nil
                ))
            } else {
                iconComponent = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "❌", font: Font.regular(25.0), textColor: .black))
                ))
            }

            let iconSize = imageIcon.update(
                transition: .immediate,
                component: iconComponent,
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.medium(10.0), textColor: iconTintColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )

            let contentWidth = max(iconSize.width, titleSize.width)

            let iconFrame = CGRect(origin: CGPoint(x: floor((contentWidth - iconSize.width) * 0.5), y: -3.0), size: iconSize)
            if let imageIconView = imageIcon.view {
                if imageIconView.superview == nil {
                    self.addSubview(imageIconView)
                }
                iconTransition.setFrame(view: imageIconView, frame: iconFrame)
            }

            let titleFrame = CGRect(origin: CGPoint(x: floor((contentWidth - titleSize.width) * 0.5), y: availableSize.height - 5.0 - titleSize.height), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }

            return CGSize(width: contentWidth, height: availableSize.height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
