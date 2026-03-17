import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import GlassBackgroundComponent
import MultilineTextComponent
import BundleIconComponent
import TelegramCore
import TranslateUI

final class TextProcessingLanguageSelectionComponent: Component {
    public struct Language: Equatable {
        public let id: String
        public let languageCode: String
        public let name: String

        public init(id: String, languageCode: String, name: String) {
            self.id = id
            self.languageCode = languageCode
            self.name = name
        }
    }

    let theme: PresentationTheme
    let strings: PresentationStrings
    let sourceView: UIView
    let topLanguages: [Language]
    let selectedLanguageCode: String
    let currentStyle: TelegramComposeAIMessageMode.Style
    let displayStyles: Bool
    let completion: (String, TelegramComposeAIMessageMode.Style) -> Void
    let dismissed: () -> Void

    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        sourceView: UIView,
        topLanguages: [Language],
        selectedLanguageCode: String,
        currentStyle: TelegramComposeAIMessageMode.Style,
        displayStyles: Bool,
        completion: @escaping (String, TelegramComposeAIMessageMode.Style) -> Void,
        dismissed: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.sourceView = sourceView
        self.topLanguages = topLanguages
        self.selectedLanguageCode = selectedLanguageCode
        self.currentStyle = currentStyle
        self.displayStyles = displayStyles
        self.completion = completion
        self.dismissed = dismissed
    }

    static func ==(lhs: TextProcessingLanguageSelectionComponent, rhs: TextProcessingLanguageSelectionComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.topLanguages != rhs.topLanguages {
            return false
        }
        if lhs.selectedLanguageCode != rhs.selectedLanguageCode {
            return false
        }
        if lhs.currentStyle != rhs.currentStyle {
            return false
        }
        if lhs.displayStyles != rhs.displayStyles {
            return false
        }
        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private struct ItemLayout: Equatable {
        let size: CGSize
        let itemHeight: CGFloat
        let itemCount: Int
        let topSeparatedItemCount: Int
        let topSeparatorHeight: CGFloat
        let verticalInset: CGFloat
        let contentHeight: CGFloat
        
        init(size: CGSize, itemHeight: CGFloat, itemCount: Int, topSeparatedItemCount: Int, verticalInset: CGFloat) {
            self.size = size
            self.itemHeight = itemHeight
            self.itemCount = itemCount
            self.topSeparatedItemCount = topSeparatedItemCount
            self.topSeparatorHeight = 20.0
            self.verticalInset = verticalInset
            var contentHeight = verticalInset * 2.0 + CGFloat(itemCount) * itemHeight
            self.contentHeight = contentHeight
            if self.topSeparatedItemCount != 0 {
                contentHeight += self.topSeparatorHeight
            }
        }
        
        func indexRange(minY: CGFloat, maxY: CGFloat) -> Range<Int>? {
            var firstIndex = Int(floor((minY - self.verticalInset - self.topSeparatorHeight) / self.itemHeight))
            firstIndex = max(0, firstIndex)
            
            var lastIndex = Int(ceil((maxY - self.verticalInset + self.topSeparatorHeight) / self.itemHeight))
            lastIndex = min(self.itemCount - 1, lastIndex)
            
            if firstIndex < lastIndex {
                return firstIndex ..< (lastIndex + 1)
            } else {
                return nil
            }
        }
        
        func frame(forItemAt index: Int) -> CGRect {
            var rect = CGRect(origin: CGPoint(x: 0.0, y: self.verticalInset + CGFloat(index) * self.itemHeight), size: CGSize(width: self.size.width, height: self.itemHeight))
            if index >= self.topSeparatedItemCount && self.topSeparatedItemCount != 0 {
                rect.origin.y += self.topSeparatorHeight
            }
            return rect
        }
    }

    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        
        private let backgroundContainer: GlassBackgroundContainerView
        private let mainBackground: GlassBackgroundView
        private let mainScrollView: ScrollView
        private var mainItemViews: [String: ComponentView<Empty>] = [:]
        private let mainMeasureItem = ComponentView<Empty>()
        
        private let mainTopSeparator: SimpleLayer
        
        private let stylesBackground: GlassBackgroundView
        private let stylesScrollView: ScrollView
        private let stylesSelectionView: UIImageView
        private var stylesItemViews: [TelegramComposeAIMessageMode.Style: ComponentView<Empty>] = [:]
        
        private var mainItems: [Language] = []
        private var mainTopItemCount: Int = 0
        
        private var mainItemLayout: ItemLayout?
        
        private var component: TextProcessingLanguageSelectionComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        private var ignoreScrolling: Bool = false
        
        private var updatedLanguage: String?
        private var updatedStyle: TelegramComposeAIMessageMode.Style?
        
        override init(frame: CGRect) {
            self.dimView = UIView()
            
            self.backgroundContainer = GlassBackgroundContainerView()
            
            self.mainBackground = GlassBackgroundView()
            self.backgroundContainer.contentView.addSubview(self.mainBackground)
            
            self.stylesBackground = GlassBackgroundView()
            
            self.mainScrollView = ScrollView()
            self.stylesScrollView = ScrollView()
            
            self.mainTopSeparator = SimpleLayer()
            self.mainScrollView.layer.addSublayer(self.mainTopSeparator)
            
            self.stylesSelectionView = UIImageView()
            self.stylesScrollView.addSubview(self.stylesSelectionView)
            
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onDimTapGesture(_:))))
            
            self.addSubview(self.backgroundContainer)
            
            self.mainScrollView.delaysContentTouches = false
            self.mainScrollView.canCancelContentTouches = true
            self.mainScrollView.contentInsetAdjustmentBehavior = .never
            self.mainScrollView.automaticallyAdjustsScrollIndicatorInsets = false
            self.mainScrollView.showsVerticalScrollIndicator = false
            self.mainScrollView.showsHorizontalScrollIndicator = false
            self.mainScrollView.alwaysBounceHorizontal = false
            self.mainScrollView.alwaysBounceVertical = true
            self.mainScrollView.scrollsToTop = false
            self.mainScrollView.delegate = self
            self.mainScrollView.clipsToBounds = true
            self.mainBackground.contentView.addSubview(self.mainScrollView)
            
            self.stylesScrollView.delaysContentTouches = false
            self.stylesScrollView.canCancelContentTouches = true
            self.stylesScrollView.contentInsetAdjustmentBehavior = .never
            self.stylesScrollView.automaticallyAdjustsScrollIndicatorInsets = false
            self.stylesScrollView.showsVerticalScrollIndicator = false
            self.stylesScrollView.showsHorizontalScrollIndicator = false
            self.stylesScrollView.alwaysBounceHorizontal = false
            self.stylesScrollView.alwaysBounceVertical = false
            self.stylesScrollView.scrollsToTop = false
            self.stylesScrollView.delegate = self
            self.stylesScrollView.clipsToBounds = true
            self.stylesBackground.contentView.addSubview(self.stylesScrollView)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func onDimTapGesture(_ recognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = recognizer.state {
                if component.displayStyles, let updatedStyle = self.updatedStyle {
                    component.completion(component.selectedLanguageCode, updatedStyle)
                }
                self.animateOut()
            }
        }
        
        private func animateIn() {
            self.mainBackground.layer.animateSpring(from: 0.001, to: 1.0, keyPath: "transform.scale", duration: 0.5)
            self.stylesBackground.layer.animateSpring(from: 0.001, to: 1.0, keyPath: "transform.scale", duration: 0.5)
            self.backgroundContainer.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
        
        private func animateOut() {
            self.mainBackground.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false)
            self.stylesBackground.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false)
            self.backgroundContainer.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] _ in
                guard let self, let component = self.component else {
                    return
                }
                component.dismissed()
            })
        }
        
        private func completeIfPossible() {
            guard let component = self.component else {
                return
            }
            if self.updatedLanguage != nil || self.updatedStyle != nil {
                component.completion(self.updatedLanguage ?? component.selectedLanguageCode, self.updatedStyle ?? component.currentStyle)
            }
            self.animateOut()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(scrollView: scrollView, transition: .immediate)
            }
        }
        
        private func updateScrolling(scrollView: UIScrollView, transition: ComponentTransition) {
            guard let component = self.component else {
                return
            }
            if scrollView == self.mainScrollView {
                guard let itemLayout = self.mainItemLayout else {
                    return
                }
                let visibleBounds = scrollView.bounds
                
                var validIds: [String] = []
                if let indexRange = itemLayout.indexRange(minY: visibleBounds.minY, maxY: visibleBounds.maxY) {
                    for index in indexRange.lowerBound ..< indexRange.upperBound {
                        if index >= self.mainItems.count {
                            break
                        }
                        let item = self.mainItems[index]
                        validIds.append(item.id)
                        
                        let itemView: ComponentView<Empty>
                        var itemTransition = transition
                        if let current = self.mainItemViews[item.id] {
                            itemView = current
                        } else {
                            itemTransition = itemTransition.withAnimation(.none)
                            itemView = ComponentView()
                            self.mainItemViews[item.id] = itemView
                        }
                        
                        let itemFrame = itemLayout.frame(forItemAt: index)
                        let _ = itemView.update(
                            transition: itemTransition,
                            component: AnyComponent(LanguageItemComponent(
                                theme: component.theme,
                                title: item.name,
                                isSelected: item.languageCode == component.selectedLanguageCode,
                                action: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.updatedLanguage = item.languageCode
                                    self.completeIfPossible()
                                }
                            )),
                            environment: {},
                            containerSize: itemFrame.size
                        )
                        if let itemComponentView = itemView.view {
                            if itemComponentView.superview == nil {
                                self.mainScrollView.addSubview(itemComponentView)
                            }
                            itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                        }
                    }
                }
                
                var removedIds: [String] = []
                for (id, itemView) in self.mainItemViews {
                    if !validIds.contains(id) {
                        removedIds.append(id)
                        itemView.view?.removeFromSuperview()
                    }
                }
                for id in removedIds {
                    self.mainItemViews.removeValue(forKey: id)
                }
            }
        }

        func update(component: TextProcessingLanguageSelectionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let containerSideInset: CGFloat = 16.0
            
            var shouldAnimateIn = false
            if self.component == nil {
                shouldAnimateIn = true
            }
            
            self.component = component
            self.state = state
            
            if self.mainItems.isEmpty {
                self.mainItems = supportedTranslationLanguages.compactMap { item in
                    return Language(id: item, languageCode: item, name: localizedLanguageName(strings: component.strings, language: item))
                }
                var topIds: [String] = []
                if !topIds.contains(component.selectedLanguageCode), let item = self.mainItems.first(where: { $0.languageCode == component.selectedLanguageCode }) {
                    self.mainItems.insert(TextProcessingLanguageSelectionComponent.Language(
                        id: "top-" + item.id,
                        languageCode: item.languageCode,
                        name: item.name
                    ), at: 0)
                    topIds.append(item.languageCode)
                }
                if !topIds.contains("en"), let item = self.mainItems.first(where: { $0.languageCode == "en" }) {
                    self.mainItems.insert(TextProcessingLanguageSelectionComponent.Language(
                        id: "top-" + item.id,
                        languageCode: item.languageCode,
                        name: item.name
                    ), at: 0)
                    topIds.append(item.languageCode)
                }
                
                var languageCode = component.strings.baseLanguageCode
                let rawSuffix = "-raw"
                if languageCode.hasSuffix(rawSuffix) {
                    languageCode = String(languageCode.dropLast(rawSuffix.count))
                }
                
                if !topIds.contains(languageCode), let item = self.mainItems.first(where: { $0.languageCode == languageCode }) {
                    self.mainItems.insert(TextProcessingLanguageSelectionComponent.Language(
                        id: "top-" + item.id,
                        languageCode: item.languageCode,
                        name: item.name
                    ), at: 0)
                    topIds.append(item.languageCode)
                }
                self.mainTopItemCount = topIds.count
            }
            
            let mainWidth: CGFloat = 220.0
            let mainContainerInset: CGFloat = 11.0
            let mainItemSize = self.mainMeasureItem.update(
                transition: .immediate,
                component: AnyComponent(LanguageItemComponent(
                    theme: component.theme,
                    title: "A",
                    isSelected: false,
                    action: {
                    }
                )),
                environment: {},
                containerSize: CGSize(width: mainWidth, height: 1000.0)
            )
            let mainContentHeight = mainContainerInset * 2.0 + CGFloat(self.mainItems.count) * mainItemSize.height
            
            var mainSize = CGSize(width: mainWidth, height: min(370.0, mainContentHeight))
            
            var stylesSize: CGSize?
            let stylesSpacing: CGFloat = 8.0
            if component.displayStyles {
                var styleData: [(id: TelegramComposeAIMessageMode.Style, icon: String, title: String)] = []
                styleData.append((.neutral, "🏳️", "Neutral"))
                styleData.append((.formal, "🤝", "Formal"))
                styleData.append((.short, "🎯", "Short"))
                styleData.append((.savage, "🍖", "Savage"))
                styleData.append((.biblical, "🕯", "Biblical"))
                styleData.append((.posh, "🍷", "Posh"))
                
                let stylesItemSize = CGSize(width: 82.0, height: 60.0)
                var selectedItemFrame: CGRect?
                stylesSize = CGSize(width: stylesItemSize.width, height: CGFloat(styleData.count) * stylesItemSize.height)
                for index in 0 ..< styleData.count {
                    let item = styleData[index]
                    let itemView: ComponentView<Empty>
                    var itemViewTransition = transition
                    if let current = self.stylesItemViews[item.id] {
                        itemView = current
                    } else {
                        itemViewTransition = itemViewTransition.withAnimation(.none)
                        itemView = ComponentView()
                        self.stylesItemViews[item.id] = itemView
                    }
                    let _ = itemView.update(
                        transition: itemViewTransition,
                        component: AnyComponent(StyleItemComponent(
                            theme: component.theme,
                            icon: item.icon,
                            title: item.title,
                            action: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.updatedStyle = item.id
                                self.completeIfPossible()
                            }
                        )),
                        environment: {},
                        containerSize: stylesItemSize
                    )
                    let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: CGFloat(index) * stylesItemSize.height), size: stylesItemSize)
                    if let itemComponentView = itemView.view {
                        if itemComponentView.superview == nil {
                            self.stylesScrollView.addSubview(itemComponentView)
                        }
                        itemViewTransition.setFrame(view: itemComponentView, frame: itemFrame)
                    }
                    if item.id == self.updatedStyle ?? component.currentStyle {
                        selectedItemFrame = itemFrame
                    }
                }
                
                if self.stylesSelectionView.image == nil {
                    self.stylesSelectionView.image = generateStretchableFilledCircleImage(diameter: (30.0 - 4.0) * 2.0, color: .white)?.withRenderingMode(.alwaysTemplate)
                }
                self.stylesSelectionView.tintColor = component.theme.list.itemHighlightedBackgroundColor.withMultipliedAlpha(0.6)
                
                if let selectedItemFrame {
                    var selectedBackgroundTransition = transition
                    if self.stylesSelectionView.isHidden {
                        self.stylesSelectionView.isHidden = false
                        selectedBackgroundTransition = selectedBackgroundTransition.withAnimation(.none)
                    }
                    selectedBackgroundTransition.setFrame(view: self.stylesSelectionView, frame: selectedItemFrame.insetBy(dx: 4.0, dy: 4.0))
                    transition.setAlpha(view: self.stylesSelectionView, alpha: 1.0)
                } else {
                    if !self.stylesSelectionView.isHidden {
                        transition.setAlpha(view: self.stylesSelectionView, alpha: 0.0, completion: { [weak self] flag in
                            guard let self, flag else {
                                return
                            }
                            self.stylesSelectionView.isHidden = true
                        })
                    }
                }
            }
            if let stylesSize {
                mainSize.height = stylesSize.height
            }
            
            let mainItemLayout = ItemLayout(size: mainSize, itemHeight: mainItemSize.height, itemCount: self.mainItems.count, topSeparatedItemCount: self.mainTopItemCount, verticalInset: mainContainerInset)
            self.mainItemLayout = mainItemLayout
            
            if mainItemLayout.topSeparatedItemCount != 0 {
                self.mainTopSeparator.backgroundColor = component.theme.contextMenu.itemSeparatorColor.cgColor
                self.mainTopSeparator.isHidden = false
                var topSeparatorFrame = CGRect(origin: CGPoint(x: 18.0, y: mainItemLayout.verticalInset + CGFloat(mainItemLayout.topSeparatedItemCount) * mainItemLayout.itemHeight), size: CGSize(width: mainItemLayout.size.width - 18.0 - 18.0, height: UIScreenPixel))
                topSeparatorFrame.origin.y += floorToScreenPixels((mainItemLayout.topSeparatorHeight - topSeparatorFrame.height) * 0.5)
                transition.setFrame(layer: self.mainTopSeparator, frame: topSeparatorFrame)
            } else {
                self.mainTopSeparator.isHidden = true
            }
            
            self.ignoreScrolling = true
            if self.mainScrollView.bounds.size != mainItemLayout.size || self.mainScrollView.contentSize.height != mainItemLayout.contentHeight {
                self.mainScrollView.frame = CGRect(origin: CGPoint(), size: mainItemLayout.size)
                self.mainScrollView.contentSize = CGSize(width: mainItemLayout.size.width, height: mainItemLayout.contentHeight)
            }
            self.ignoreScrolling = false
            self.updateScrolling(scrollView: self.mainScrollView, transition: transition)
            
            transition.setFrame(view: self.backgroundContainer, frame: CGRect(origin: CGPoint(), size: availableSize))
            self.backgroundContainer.update(size: availableSize, isDark: component.theme.overallDarkAppearance, transition: transition)
            
            let sourceLocation = component.sourceView.convert(component.sourceView.bounds.center, to: self)
            var mainFrame = CGRect(origin: CGPoint(x: floor(sourceLocation.x - mainItemLayout.size.width * 0.5), y: floor(sourceLocation.y - mainItemLayout.size.height * 0.5)), size: mainItemLayout.size)
            if mainFrame.origin.x + mainFrame.size.width > availableSize.width - containerSideInset {
                mainFrame.origin.x = availableSize.width - containerSideInset - mainFrame.size.width
            }
            if mainFrame.origin.y + mainFrame.size.height > availableSize.height - containerSideInset {
                mainFrame.origin.y = availableSize.height - containerSideInset - mainFrame.size.height
            }
            if mainFrame.origin.x < containerSideInset {
                mainFrame.origin.x = containerSideInset
            }
            if mainFrame.origin.y < containerSideInset {
                mainFrame.origin.y = containerSideInset
            }
            
            transition.setFrame(view: self.mainBackground, frame: mainFrame)
            self.mainBackground.update(size: mainFrame.size, cornerRadius: 30.0, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
            
            if let stylesSize {
                let stylesFrame = CGRect(origin: CGPoint(x: mainFrame.maxX + stylesSpacing, y: mainFrame.minY), size: stylesSize)
                if self.stylesBackground.superview == nil {
                    self.backgroundContainer.contentView.addSubview(self.stylesBackground)
                }
                transition.setFrame(view: self.stylesBackground, frame: stylesFrame)
                self.stylesBackground.update(size: stylesFrame.size, cornerRadius: 30.0, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
                
                transition.setFrame(view: self.stylesScrollView, frame: CGRect(origin: CGPoint(), size: stylesFrame.size))
                self.stylesScrollView.contentSize = stylesFrame.size
            }
            
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            if shouldAnimateIn {
                self.animateIn()
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

private final class LanguageItemComponent: Component {
    let theme: PresentationTheme
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    init(
        theme: PresentationTheme,
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }
    
    static func ==(lhs: LanguageItemComponent, rhs: LanguageItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var imageIcon: ComponentView<Empty>?
        private let title = ComponentView<Empty>()
        
        private var component: LanguageItemComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = recognizer.state {
                component.action()
            }
        }
        
        func update(component: LanguageItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let size = CGSize(width: availableSize.width, height: 42.0)
            
            let leftTitleInset: CGFloat = 60.0
            let rightTitleInset: CGFloat = 8.0

            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.regular(17.0), textColor: component.theme.contextMenu.primaryColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftTitleInset - rightTitleInset, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: leftTitleInset, y: floorToScreenPixels((size.height - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            if component.isSelected {
                let imageIcon: ComponentView<Empty>
                var imageIconTransition = transition
                if let current = self.imageIcon {
                    imageIcon = current
                } else {
                    imageIconTransition = imageIconTransition.withAnimation(.none)
                    imageIcon = ComponentView()
                    self.imageIcon = imageIcon
                }
                let imageIconSize = imageIcon.update(
                    transition: imageIconTransition,
                    component: AnyComponent(BundleIconComponent(
                        name: "Chat/Context Menu/Check",
                        tintColor: component.theme.contextMenu.primaryColor
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let imageIconFrame = CGRect(origin: CGPoint(x: 23.0, y: floorToScreenPixels((size.height - imageIconSize.height) * 0.5)), size: imageIconSize)
                if let imageIconView = imageIcon.view {
                    if imageIconView.superview == nil {
                        imageIconView.isUserInteractionEnabled = false
                        self.addSubview(imageIconView)
                    }
                    imageIconTransition.setFrame(view: imageIconView, frame: imageIconFrame)
                }
            } else {
                if let imageIcon = self.imageIcon {
                    self.imageIcon = nil
                    imageIcon.view?.removeFromSuperview()
                }
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

private final class StyleItemComponent: Component {
    let theme: PresentationTheme
    let icon: String
    let title: String
    let action: () -> Void
    
    init(
        theme: PresentationTheme,
        icon: String,
        title: String,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.icon = icon
        self.title = title
        self.action = action
    }
    
    static func ==(lhs: StyleItemComponent, rhs: StyleItemComponent) -> Bool {
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
        
        private var component: StyleItemComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = recognizer.state {
                component.action()
            }
        }
        
        func update(component: StyleItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
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
            let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: 8.0), size: iconSize)
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
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: availableSize.height - 9.0 - titleSize.height), size: titleSize)
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
