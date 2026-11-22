import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import MultilineTextComponent
import TelegramCore
import EmojiStatusComponent
import AccountContext
import BundleIconComponent
import GlassBackgroundComponent
import ComponentDisplayAdapters

final class TextProcessingStyleSelectionComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let styles: [TextProcessingScreen.Style]
    let selectedStyle: TelegramComposeAIMessageMode.StyleId
    let updateStyle: (TelegramComposeAIMessageMode.StyleReference) -> Void
    let createStyle: () -> Void
    let openStyleContextMenu: (TelegramComposeAIMessageMode.StyleReference, ContextGesture, ContextExtractedContentContainingView) -> Void

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        styles: [TextProcessingScreen.Style],
        selectedStyle: TelegramComposeAIMessageMode.StyleId,
        updateStyle: @escaping (TelegramComposeAIMessageMode.StyleReference) -> Void,
        createStyle: @escaping () -> Void,
        openStyleContextMenu: @escaping (TelegramComposeAIMessageMode.StyleReference, ContextGesture, ContextExtractedContentContainingView) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.styles = styles
        self.selectedStyle = selectedStyle
        self.updateStyle = updateStyle
        self.createStyle = createStyle
        self.openStyleContextMenu = openStyleContextMenu
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

        private let contextGestureContainerView: ContextControllerSourceView
        private let scrollView: ScrollView
        private var itemViews: [TelegramComposeAIMessageMode.StyleId: ComponentView<Empty>] = [:]
        private let promptItemView = ComponentView<Empty>()
        private let createStyleItemView = ComponentView<Empty>()
        private let selectedBackgroundView: UIImageView
        
        private var itemWithActiveContextGesture: TelegramComposeAIMessageMode.StyleId?

        override init(frame: CGRect) {
            self.contextGestureContainerView = ContextControllerSourceView()
            self.contextGestureContainerView.isGestureEnabled = true
            self.contextGestureContainerView.useSublayerTransformForActivation = true
            
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
            self.addSubview(self.contextGestureContainerView)
            
            self.scrollView.addSubview(self.selectedBackgroundView)
            self.contextGestureContainerView.addSubview(self.scrollView)

            self.scrollView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
            
            self.contextGestureContainerView.shouldBegin = { [weak self] point in
                guard let self, let component = self.component else {
                    return false
                }
                guard let (itemId, itemView) = self.item(at: point) else {
                    return false
                }
                guard let item = component.styles.first(where: { .style($0.reference.id) == itemId }) else {
                    return false
                }
                guard case .custom = item.reference else {
                    return false
                }
                guard let itemComponentView = itemView.view as? ItemComponent.View else {
                    return false
                }
                
                self.itemWithActiveContextGesture = itemId
                self.contextGestureContainerView.targetLayerForActivationProgress = itemComponentView.containerView.layer
                
                let startPoint = point
                self.contextGestureContainerView.contextGesture?.externalUpdated = { [weak self] _, point in
                    guard let self else {
                        return
                    }
                    
                    let dist = sqrt(pow(startPoint.x - point.x, 2.0) + pow(startPoint.y - point.y, 2.0))
                    if dist > 10.0 {
                        self.contextGestureContainerView.contextGesture?.cancel()
                    }
                }
                
                return true
            }
            self.contextGestureContainerView.activated = { [weak self] gesture, _ in
                guard let self, let component = self.component else {
                    return
                }
                guard let itemWithActiveContextGesture = self.itemWithActiveContextGesture else {
                    return
                }
                
                var itemView: ItemComponent.View?
                itemView = self.itemViews[itemWithActiveContextGesture]?.view as? ItemComponent.View
                
                guard let itemView else {
                    return
                }
                guard let item = component.styles.first(where: { .style($0.reference.id) == itemWithActiveContextGesture }) else {
                    return
                }
                component.openStyleContextMenu(item.id, gesture, itemView.contextContainerView)
            }
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        private func item(at point: CGPoint) -> (id: TelegramComposeAIMessageMode.StyleId, itemView: ComponentView<Empty>)? {
            for (id, itemView) in self.itemViews {
                if let itemComponentView = itemView.view {
                    if itemComponentView.bounds.contains(self.scrollView.convert(self.convert(point, to: self.scrollView), to: itemComponentView)) {
                        return (id, itemView)
                    }
                }
            }
            return nil
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
                                if let style = component.styles.first(where: { .style($0.reference.id) == id }) {
                                    component.updateStyle(.style(style.reference))
                                }
                            }
                            self.scrollView.scrollRectToVisible(itemComponentView.frame.insetBy(dx: -100.0, dy: 0.0), animated: true)
                            break
                        }
                    }
                }
                if let itemComponentView = self.createStyleItemView.view {
                    if itemComponentView.bounds.contains(self.scrollView.convert(recognizer.location(in: self.scrollView), to: itemComponentView)) {
                        component.createStyle()
                    }
                }
                if let itemComponentView = self.promptItemView.view {
                    if itemComponentView.bounds.contains(self.scrollView.convert(recognizer.location(in: self.scrollView), to: itemComponentView)) {
                        component.updateStyle(.prompt(""))
                    }
                }
            }
        }
        
        func scrollToStart() {
            let transition: ComponentTransition = .spring(duration: 0.4)
            transition.setBounds(view: self.scrollView, bounds: CGRect(origin: CGPoint(), size: self.scrollView.bounds.size))
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
                if let current = self.itemViews[.style(style.reference.id)] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = ComponentView()
                    self.itemViews[.style(style.reference.id)] = itemView
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
                itemSizes[.style(style.reference.id)] = measuredSize
            }
            
            let createStyleItemSize: CGSize = self.createStyleItemView.update(
                transition: transition,
                component: AnyComponent(ServiceItemComponent(
                    theme: component.theme,
                    strings: component.strings,
                    kind: .create
                )),
                environment: {},
                containerSize: CGSize(width: maxItemWidth, height: availableSize.height)
            )
            
            let promptItemSize: CGSize = self.promptItemView.update(
                transition: transition,
                component: AnyComponent(ServiceItemComponent(
                    theme: component.theme,
                    strings: component.strings,
                    kind: .prompt
                )),
                environment: {},
                containerSize: CGSize(width: maxItemWidth, height: availableSize.height)
            )

            // Compute uniform slot width from largest item
            var largestItemWidth: CGFloat = 0.0
            for (_, size) in itemSizes {
                largestItemWidth = max(largestItemWidth, size.width)
            }
            largestItemWidth = max(largestItemWidth, createStyleItemSize.width)
            
            let contentBasedWidth = min(maxSlotWidth, max(minSlotWidth, largestItemWidth + itemPadding))
            let slotWidth: CGFloat
            if CGFloat(component.styles.count + 1) * contentBasedWidth <= availableSize.width {
                slotWidth = floor(availableSize.width / CGFloat(component.styles.count + 1))
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
            let contentWidth = slotWidth * CGFloat(component.styles.count + 2)

            self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            self.scrollView.contentSize = CGSize(width: contentWidth, height: availableSize.height)
            self.scrollView.alwaysBounceHorizontal = contentWidth > availableSize.width
            self.contextGestureContainerView.frame = CGRect(origin: CGPoint(), size: availableSize)
            
            var selectedItemFrame: CGRect?
            
            do {
                let naturalSize = promptItemSize
                let slotOriginX = 0.0 * slotWidth
                let itemX = slotOriginX + floor((slotWidth - naturalSize.width) * 0.5)
                let itemFrame = CGRect(origin: CGPoint(x: itemX, y: 0.0), size: naturalSize)
                if let itemComponentView = self.promptItemView.view {
                    if itemComponentView.superview == nil {
                        self.scrollView.addSubview(itemComponentView)
                    }
                    transition.setFrame(view: itemComponentView, frame: itemFrame)
                }
                if case .prompt = component.selectedStyle {
                    let displayItemFrame = CGSize(width: slotWidth, height: itemFrame.height).centered(in: itemFrame)
                    selectedItemFrame = CGRect(origin: CGPoint(x: displayItemFrame.minX, y: -5.0), size: CGSize(width: slotWidth, height: availableSize.height + 5.0 + 3.0))
                }
            }
            
            do {
                let naturalSize = createStyleItemSize
                let slotOriginX = 1.0 * slotWidth
                let itemX = slotOriginX + floor((slotWidth - naturalSize.width) * 0.5)
                let itemFrame = CGRect(origin: CGPoint(x: itemX, y: 0.0), size: naturalSize)
                if let itemComponentView = self.createStyleItemView.view {
                    if itemComponentView.superview == nil {
                        self.scrollView.addSubview(itemComponentView)
                    }
                    transition.setFrame(view: itemComponentView, frame: itemFrame)
                }
            }

            // Second pass: position items centered in their slots
            for i in 0 ..< component.styles.count {
                let style = component.styles[i]
                guard let itemView = self.itemViews[.style(style.reference.id)],
                      let naturalSize = itemSizes[.style(style.reference.id)] else {
                    continue
                }
                let itemSize = CGSize(width: slotWidth, height: naturalSize.height)
                let itemFrame = CGRect(origin: CGPoint(x: CGFloat(i + 2) * slotWidth, y: 0.0), size: itemSize)
                if let itemComponentView = itemView.view as? ItemComponent.View {
                    var itemTransition = transition
                    if itemComponentView.superview == nil {
                        self.scrollView.addSubview(itemComponentView)
                        itemTransition = itemTransition.withAnimation(.none)
                        transition.animateScale(view: itemComponentView, from: 0.001, to: 1.0)
                        transition.animateAlpha(view: itemComponentView, from: 0.0, to: 1.0)
                    }
                    itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                    itemComponentView.applySize(measuredSize: naturalSize, size: itemSize, transition: itemTransition)
                }
                if .style(style.reference.id) == component.selectedStyle {
                    selectedItemFrame = CGRect(origin: CGPoint(x: itemFrame.minX, y: -5.0), size: CGSize(width: slotWidth, height: availableSize.height + 5.0 + 3.0))
                }
            }

            var removedIds: [TelegramComposeAIMessageMode.StyleId] = []
            for (id, itemView) in self.itemViews {
                if !component.styles.contains(where: { .style($0.reference.id) == id }) {
                    removedIds.append(id)
                    if let itemComponentView = itemView.view {
                        transition.setAlpha(view: itemComponentView, alpha: 0.0, completion: { [weak itemComponentView] _ in
                            itemComponentView?.removeFromSuperview()
                        })
                        transition.setScale(view: itemComponentView, scale: 0.001)
                    }
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
        let contextContainerView: ContextExtractedContentContainingView
        let containerView: UIView
        private let backgroundContainer: GlassBackgroundContainerView
        private let backgroundView: GlassBackgroundView
        
        private var imageIcon: ComponentView<Empty>?
        private let title = ComponentView<Empty>()
        
        private var component: ItemComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            self.contextContainerView = ContextExtractedContentContainingView()
            self.containerView = UIView()
            
            self.backgroundContainer = GlassBackgroundContainerView()
            self.backgroundContainer.alpha = 0.0
            self.backgroundView = GlassBackgroundView()
            self.backgroundContainer.contentView.addSubview(self.backgroundView)
            
            super.init(frame: frame)
            
            self.addSubview(self.contextContainerView)
            self.contextContainerView.contentView.addSubview(self.backgroundContainer)
            self.contextContainerView.contentView.addSubview(self.containerView)
            
            self.contextContainerView.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
                guard let self else {
                    return
                }
                let transition: ComponentTransition = transition.isAnimated ? .easeInOut(duration: 0.25) : .immediate
                if isExtracted {
                    transition.setAlpha(view: self.backgroundContainer, alpha: 1.0)
                } else {
                    transition.setAlpha(view: self.backgroundContainer, alpha: 0.001)
                }
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func applySize(measuredSize: CGSize, size: CGSize, transition: ComponentTransition) {
            guard let component = self.component else {
                return
            }
            
            let containerFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - measuredSize.width) * 0.5), y: floor((measuredSize.height - size.height) * 0.5)), size: measuredSize)
            let contentRect = CGRect(origin: CGPoint(x: 0.0, y: -5.0 - 4.0), size: CGSize(width: size.width + 0.0, height: size.height + 5.0 + 3.0 + 6.0))
            transition.setFrame(view: self.backgroundContainer, frame: contentRect)
            self.backgroundContainer.update(size: contentRect.size, isDark: component.theme.overallDarkAppearance, transition: transition)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: contentRect.size))
            self.backgroundView.update(size: contentRect.size, cornerRadius: 20.0, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), transition: transition)
            
            transition.setFrame(view: self.containerView, frame: containerFrame)
            transition.setFrame(view: self.contextContainerView, frame: CGRect(origin: CGPoint(), size: size))
            transition.setFrame(view: self.contextContainerView.contentView, frame: CGRect(origin: CGPoint(), size: size))
            self.contextContainerView.contentRect = contentRect.insetBy(dx: -2.0, dy: -2.0)
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
                    self.containerView.addSubview(imageIconView)
                }
                iconTransition.setFrame(view: imageIconView, frame: iconFrame)
            }

            let titleFrame = CGRect(origin: CGPoint(x: floor((contentWidth - titleSize.width) * 0.5), y: availableSize.height - 5.0 - titleSize.height), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.containerView.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            let size = CGSize(width: contentWidth, height: availableSize.height)
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

private final class ServiceItemComponent: Component {
    enum Kind {
        case create
        case prompt
    }
    
    let theme: PresentationTheme
    let strings: PresentationStrings
    let kind: Kind
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        kind: Kind
    ) {
        self.theme = theme
        self.strings = strings
        self.kind = kind
    }
    
    static func ==(lhs: ServiceItemComponent, rhs: ServiceItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.kind != rhs.kind {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let icon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        
        private var component: ServiceItemComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ServiceItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state

            let iconTintColor = component.theme.list.itemPrimaryTextColor

            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: component.kind == .prompt ? "TextProcessing/PromptStyle" : "TextProcessing/NewStyle",
                    tintColor: iconTintColor
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.kind == .prompt ? component.strings.TextProcessing_StyleList_Prompt : component.strings.TextProcessing_StyleList_Add, font: Font.medium(10.0), textColor: iconTintColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )

            let contentWidth = max(iconSize.width, titleSize.width)

            let iconFrame = CGRect(origin: CGPoint(x: floor((contentWidth - iconSize.width) * 0.5), y: -3.0), size: iconSize)
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                }
                transition.setFrame(view: iconView, frame: iconFrame)
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
