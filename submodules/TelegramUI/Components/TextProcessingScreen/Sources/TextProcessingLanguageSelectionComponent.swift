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
import EmojiStatusComponent
import AccountContext

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

    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let sourceView: UIView
    let topLanguages: [Language]
    let selectedLanguageCode: String
    let currentStyle: TelegramComposeAIMessageMode.StyleId
    let displayStyles: [TextProcessingScreen.Style]?
    let completion: (String, TelegramComposeAIMessageMode.StyleId) -> Void
    let dismissed: () -> Void
    let inputHeight: CGFloat

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        sourceView: UIView,
        topLanguages: [Language],
        selectedLanguageCode: String,
        currentStyle: TelegramComposeAIMessageMode.StyleId,
        displayStyles: [TextProcessingScreen.Style]?,
        completion: @escaping (String, TelegramComposeAIMessageMode.StyleId) -> Void,
        dismissed: @escaping () -> Void,
        inputHeight: CGFloat
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.sourceView = sourceView
        self.topLanguages = topLanguages
        self.selectedLanguageCode = selectedLanguageCode
        self.currentStyle = currentStyle
        self.displayStyles = displayStyles
        self.completion = completion
        self.dismissed = dismissed
        self.inputHeight = inputHeight
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
        if lhs.inputHeight != rhs.inputHeight {
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
        let searchSeparatorHeight: CGFloat
        let verticalInset: CGFloat
        let searchItemHeight: CGFloat
        let contentHeight: CGFloat

        init(size: CGSize, itemHeight: CGFloat, itemCount: Int, topSeparatedItemCount: Int, verticalInset: CGFloat, searchItemHeight: CGFloat) {
            self.size = size
            self.itemHeight = itemHeight
            self.itemCount = itemCount
            self.topSeparatedItemCount = topSeparatedItemCount
            self.topSeparatorHeight = 20.0
            self.searchSeparatorHeight = 20.0
            self.verticalInset = verticalInset
            self.searchItemHeight = searchItemHeight
            var contentHeight = verticalInset * 2.0 + searchItemHeight + self.searchSeparatorHeight + CGFloat(itemCount) * itemHeight
            if topSeparatedItemCount != 0 {
                contentHeight += self.topSeparatorHeight
            }
            self.contentHeight = contentHeight
        }

        func indexRange(minY: CGFloat, maxY: CGFloat) -> Range<Int>? {
            let itemsOriginY = self.verticalInset + self.searchItemHeight + self.searchSeparatorHeight
            var firstIndex = Int(floor((minY - itemsOriginY - self.topSeparatorHeight) / self.itemHeight))
            firstIndex = max(0, firstIndex)

            var lastIndex = Int(ceil((maxY - itemsOriginY + self.topSeparatorHeight) / self.itemHeight))
            lastIndex = min(self.itemCount - 1, lastIndex)

            if firstIndex <= lastIndex {
                return firstIndex ..< (lastIndex + 1)
            } else {
                return nil
            }
        }

        func frame(forItemAt index: Int) -> CGRect {
            let itemsOriginY = self.verticalInset + self.searchItemHeight + self.searchSeparatorHeight
            var rect = CGRect(origin: CGPoint(x: 0.0, y: itemsOriginY + CGFloat(index) * self.itemHeight), size: CGSize(width: self.size.width, height: self.itemHeight))
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
        
        private let mainSearchSeparator: SimpleLayer
        private let mainTopSeparator: SimpleLayer
        
        private let stylesBackground: GlassBackgroundView
        private let stylesScrollView: ScrollView
        private let stylesSelectionView: UIImageView
        private var stylesItemViews: [TelegramComposeAIMessageMode.StyleId: ComponentView<Empty>] = [:]
        
        private var mainItems: [Language] = []
        private var mainTopItemCount: Int = 0
        
        private var mainItemLayout: ItemLayout?
        
        private var component: TextProcessingLanguageSelectionComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        private var ignoreScrolling: Bool = false
        
        private var updatedLanguage: String?
        private var updatedStyle: TelegramComposeAIMessageMode.StyleId?

        private var searchQuery: String = "" {
            didSet {
                if self.searchQuery != oldValue {
                    self.cachedFilteredItems = nil
                }
            }
        }
        private var searchItemView = ComponentView<Empty>()
        private let searchExternalState = SearchItemComponent.ExternalState()
        private var cachedFilteredItems: [Language]?

        private var filteredMainItems: [Language] {
            if let cached = self.cachedFilteredItems {
                return cached
            }
            let result: [Language]
            if self.searchQuery.isEmpty {
                result = self.mainItems
            } else {
                let query = self.searchQuery.lowercased()
                result = self.mainItems.filter { item in
                    if item.id.hasPrefix("top-") {
                        return false
                    }
                    return item.name.lowercased().contains(query)
                }
            }
            self.cachedFilteredItems = result
            return result
        }

        override init(frame: CGRect) {
            self.dimView = UIView()
            
            self.backgroundContainer = GlassBackgroundContainerView()
            
            self.mainBackground = GlassBackgroundView()
            self.backgroundContainer.contentView.addSubview(self.mainBackground)
            
            self.stylesBackground = GlassBackgroundView()
            
            self.mainScrollView = ScrollView()
            self.stylesScrollView = ScrollView()
            
            self.mainSearchSeparator = SimpleLayer()
            self.mainScrollView.layer.addSublayer(self.mainSearchSeparator)
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
                if component.displayStyles != nil, let updatedStyle = self.updatedStyle {
                    component.completion(component.selectedLanguageCode, updatedStyle)
                }
                self.animateOut()
            }
        }
        
        private func animateIn() {
            self.backgroundContainer.layer.animateSpring(from: 0.001, to: 1.0, keyPath: "transform.scale", duration: 0.5)
            self.backgroundContainer.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
        
        private func animateOut() {
            self.endEditing(true)
            self.backgroundContainer.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false)
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
                let isSearchFocused = self.searchExternalState.isEditing
                let fixedSearchHeight = itemLayout.searchItemHeight + itemLayout.searchSeparatorHeight
                let scrollOffset: CGFloat = isSearchFocused ? fixedSearchHeight : 0.0
                let visibleBounds = scrollView.bounds.offsetBy(dx: 0.0, dy: scrollOffset)

                var validIds: [String] = []
                let displayItems = self.filteredMainItems
                if let indexRange = itemLayout.indexRange(minY: visibleBounds.minY, maxY: visibleBounds.maxY) {
                    for index in indexRange.lowerBound ..< indexRange.upperBound {
                        if index >= displayItems.count {
                            break
                        }
                        let item = displayItems[index]
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
                        
                        var itemFrame = itemLayout.frame(forItemAt: index)
                        itemFrame.origin.y -= scrollOffset
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
                    return Language(id: item, languageCode: item, name: localizedLanguageName(strings: component.strings, language: item, kind: .neutral))
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
            let searchItemHeight: CGFloat = mainItemSize.height
            let filteredItems = self.filteredMainItems
            let effectiveTopItemCount = self.searchQuery.isEmpty ? self.mainTopItemCount : 0
            let searchSeparatorHeight: CGFloat = 20.0
            let totalTopItemCount = self.mainTopItemCount
            let mainContentHeight = mainContainerInset * 2.0 + searchItemHeight + searchSeparatorHeight + CGFloat(self.mainItems.count) * mainItemSize.height + (totalTopItemCount != 0 ? 20.0 : 0.0)
            
            let maxAvailableHeight = max(mainItemSize.height * 2.0, availableSize.height - component.inputHeight - containerSideInset * 2.0)
            var mainSize = CGSize(width: mainWidth, height: min(min(370.0, maxAvailableHeight), mainContentHeight))
            
            var stylesSize: CGSize?
            var selectedStyleItemFrame: CGRect?
            let stylesSpacing: CGFloat = 8.0
            if let displayStyles = component.displayStyles {
                var styleData: [(id: TelegramComposeAIMessageMode.StyleId, iconFileId: Int64?, iconFile: TelegramMediaFile?, title: String)] = []
                styleData.append((.neutral, nil, nil, component.strings.TextProcessingStyle_Neutral))
                for item in displayStyles {
                    styleData.append((item.id, item.emojiFileId, item.emojiFile, item.title))
                }

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
                            context: component.context,
                            theme: component.theme,
                            iconFileId: item.iconFileId,
                            iconFile: item.iconFile,
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
                selectedStyleItemFrame = selectedItemFrame
            }
            let stylesContentSize = stylesSize
            if var stylesSizeValue = stylesSize {
                let stylesItemHeight: CGFloat = 60.0
                let maxHeight = min(370.0, maxAvailableHeight)
                if stylesSizeValue.height > maxHeight {
                    let n = floor(maxHeight / stylesItemHeight)
                    let visibleHeight = (n - 0.5) * stylesItemHeight
                    stylesSizeValue.height = max(stylesItemHeight, visibleHeight)
                } else {
                    stylesSizeValue.height = min(stylesSizeValue.height, maxHeight)
                }
                stylesSize = stylesSizeValue
                mainSize.height = min(mainSize.height, stylesSizeValue.height)
            }
            
            let mainItemLayout = ItemLayout(size: mainSize, itemHeight: mainItemSize.height, itemCount: filteredItems.count, topSeparatedItemCount: effectiveTopItemCount, verticalInset: mainContainerInset, searchItemHeight: searchItemHeight)
            self.mainItemLayout = mainItemLayout

            let _ = self.searchItemView.update(
                transition: transition,
                component: AnyComponent(SearchItemComponent(
                    theme: component.theme,
                    placeholder: component.strings.Common_Search,
                    externalState: self.searchExternalState,
                    valueChanged: { [weak self] query in
                        guard let self else {
                            return
                        }
                        self.searchQuery = query
                        if !self.isUpdating {
                            self.state?.updated(transition: .immediate)
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: mainSize.width, height: searchItemHeight)
            )
            let isSearchFocused = self.searchExternalState.isEditing
            if let searchView = self.searchItemView.view {
                if isSearchFocused {
                    if searchView.superview !== self.mainBackground.contentView {
                        self.mainBackground.contentView.addSubview(searchView)
                    }
                    transition.setFrame(view: searchView, frame: CGRect(origin: CGPoint(x: 0.0, y: mainContainerInset), size: CGSize(width: mainSize.width, height: searchItemHeight)))
                } else {
                    if searchView.superview !== self.mainScrollView {
                        self.mainScrollView.addSubview(searchView)
                    }
                    transition.setFrame(view: searchView, frame: CGRect(origin: CGPoint(x: 0.0, y: mainContainerInset), size: CGSize(width: mainSize.width, height: searchItemHeight)))
                }
            }

            self.mainSearchSeparator.backgroundColor = component.theme.contextMenu.itemSeparatorColor.cgColor
            if isSearchFocused {
                if self.mainSearchSeparator.superlayer !== self.mainBackground.contentView.layer {
                    self.mainBackground.contentView.layer.addSublayer(self.mainSearchSeparator)
                }
                var searchSeparatorFrame = CGRect(origin: CGPoint(x: 18.0, y: mainContainerInset + searchItemHeight), size: CGSize(width: mainItemLayout.size.width - 18.0 - 18.0, height: UIScreenPixel))
                searchSeparatorFrame.origin.y += floorToScreenPixels((mainItemLayout.searchSeparatorHeight - searchSeparatorFrame.height) * 0.5)
                transition.setFrame(layer: self.mainSearchSeparator, frame: searchSeparatorFrame)
            } else {
                if self.mainSearchSeparator.superlayer !== self.mainScrollView.layer {
                    self.mainScrollView.layer.addSublayer(self.mainSearchSeparator)
                }
                var searchSeparatorFrame = CGRect(origin: CGPoint(x: 18.0, y: mainItemLayout.verticalInset + mainItemLayout.searchItemHeight), size: CGSize(width: mainItemLayout.size.width - 18.0 - 18.0, height: UIScreenPixel))
                searchSeparatorFrame.origin.y += floorToScreenPixels((mainItemLayout.searchSeparatorHeight - searchSeparatorFrame.height) * 0.5)
                transition.setFrame(layer: self.mainSearchSeparator, frame: searchSeparatorFrame)
            }

            let fixedSearchHeight = searchItemHeight + mainItemLayout.searchSeparatorHeight
            let topSeparatorScrollOffset: CGFloat = isSearchFocused ? fixedSearchHeight : 0.0
            if mainItemLayout.topSeparatedItemCount != 0 {
                self.mainTopSeparator.backgroundColor = component.theme.contextMenu.itemSeparatorColor.cgColor
                self.mainTopSeparator.isHidden = false
                var topSeparatorFrame = CGRect(origin: CGPoint(x: 18.0, y: mainItemLayout.verticalInset + mainItemLayout.searchItemHeight + mainItemLayout.searchSeparatorHeight + CGFloat(mainItemLayout.topSeparatedItemCount) * mainItemLayout.itemHeight - topSeparatorScrollOffset), size: CGSize(width: mainItemLayout.size.width - 18.0 - 18.0, height: UIScreenPixel))
                topSeparatorFrame.origin.y += floorToScreenPixels((mainItemLayout.topSeparatorHeight - topSeparatorFrame.height) * 0.5)
                transition.setFrame(layer: self.mainTopSeparator, frame: topSeparatorFrame)
            } else {
                self.mainTopSeparator.isHidden = true
            }
            self.ignoreScrolling = true
            if isSearchFocused {
                let scrollViewOriginY = fixedSearchHeight
                let scrollViewHeight = mainItemLayout.size.height - fixedSearchHeight
                self.mainScrollView.frame = CGRect(origin: CGPoint(x: 0.0, y: scrollViewOriginY), size: CGSize(width: mainItemLayout.size.width, height: max(0.0, scrollViewHeight)))
                self.mainScrollView.contentSize = CGSize(width: mainItemLayout.size.width, height: mainItemLayout.contentHeight - fixedSearchHeight)
                self.mainScrollView.contentOffset = .zero
            } else {
                self.mainScrollView.frame = CGRect(origin: CGPoint(), size: mainItemLayout.size)
                self.mainScrollView.contentSize = CGSize(width: mainItemLayout.size.width, height: mainItemLayout.contentHeight)
            }
            self.ignoreScrolling = false
            self.updateScrolling(scrollView: self.mainScrollView, transition: transition)
            
            let sourceLocation = component.sourceView.convert(component.sourceView.bounds.center, to: self)
            let effectiveBottomBound = availableSize.height - component.inputHeight
            var mainFrame = CGRect(origin: CGPoint(x: floor(sourceLocation.x - mainItemLayout.size.width * 0.5), y: floor(sourceLocation.y - mainItemLayout.size.height * 0.5)), size: mainItemLayout.size)
            if mainFrame.origin.x + mainFrame.size.width > availableSize.width - containerSideInset {
                mainFrame.origin.x = availableSize.width - containerSideInset - mainFrame.size.width
            }
            if mainFrame.origin.y + mainFrame.size.height > effectiveBottomBound - containerSideInset {
                mainFrame.origin.y = effectiveBottomBound - containerSideInset - mainFrame.size.height
            }
            if mainFrame.origin.x < containerSideInset {
                mainFrame.origin.x = containerSideInset
            }
            if mainFrame.origin.y < containerSideInset {
                mainFrame.origin.y = containerSideInset
            }

            let containerInset: CGFloat = 100.0
            var unionRect = mainFrame
            var stylesFrame: CGRect?
            if let stylesSize {
                let frame = CGRect(origin: CGPoint(x: mainFrame.maxX + stylesSpacing, y: mainFrame.minY), size: stylesSize)
                stylesFrame = frame
                unionRect = unionRect.union(frame)
            }
            let containerFrame = unionRect.insetBy(dx: -containerInset, dy: -containerInset)

            let anchorX = (sourceLocation.x - containerFrame.minX) / containerFrame.width
            let anchorY = (sourceLocation.y - containerFrame.minY) / containerFrame.height
            self.backgroundContainer.layer.anchorPoint = CGPoint(x: anchorX, y: anchorY)
            self.backgroundContainer.layer.position = CGPoint(x: containerFrame.minX + anchorX * containerFrame.width, y: containerFrame.minY + anchorY * containerFrame.height)
            self.backgroundContainer.bounds = CGRect(origin: .zero, size: containerFrame.size)
            self.backgroundContainer.update(size: containerFrame.size, isDark: component.theme.overallDarkAppearance, transition: transition)

            let mainLocalFrame = CGRect(origin: CGPoint(x: mainFrame.minX - containerFrame.minX, y: mainFrame.minY - containerFrame.minY), size: mainFrame.size)
            transition.setFrame(view: self.mainBackground, frame: mainLocalFrame)
            self.mainBackground.update(size: mainFrame.size, cornerRadius: 30.0, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)

            if let stylesFrame {
                let stylesLocalFrame = CGRect(origin: CGPoint(x: stylesFrame.minX - containerFrame.minX, y: stylesFrame.minY - containerFrame.minY), size: stylesFrame.size)
                if self.stylesBackground.superview == nil {
                    self.backgroundContainer.contentView.addSubview(self.stylesBackground)
                }
                transition.setFrame(view: self.stylesBackground, frame: stylesLocalFrame)
                self.stylesBackground.update(size: stylesFrame.size, cornerRadius: 30.0, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)

                transition.setFrame(view: self.stylesScrollView, frame: CGRect(origin: CGPoint(), size: stylesFrame.size))
                self.stylesScrollView.contentSize = stylesContentSize ?? stylesFrame.size

                if shouldAnimateIn, let selectedStyleItemFrame {
                    let visibleHeight = stylesFrame.size.height
                    let maxOffsetY = max(0.0, (stylesContentSize ?? stylesFrame.size).height - visibleHeight)
                    let targetOffsetY = min(max(0.0, selectedStyleItemFrame.midY - visibleHeight * 0.5), maxOffsetY)
                    self.stylesScrollView.contentOffset = CGPoint(x: 0.0, y: targetOffsetY)
                }
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
    let context: AccountContext
    let theme: PresentationTheme
    let iconFileId: Int64?
    let iconFile: TelegramMediaFile?
    let title: String
    let action: () -> Void

    init(
        context: AccountContext,
        theme: PresentationTheme,
        iconFileId: Int64?,
        iconFile: TelegramMediaFile?,
        title: String,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.iconFileId = iconFileId
        self.iconFile = iconFile
        self.title = title
        self.action = action
    }

    static func ==(lhs: StyleItemComponent, rhs: StyleItemComponent) -> Bool {
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

private final class SearchItemComponent: Component {
    final class ExternalState {
        var isEditing: Bool = false
    }

    let theme: PresentationTheme
    let placeholder: String
    let externalState: ExternalState
    let valueChanged: (String) -> Void

    init(
        theme: PresentationTheme,
        placeholder: String,
        externalState: ExternalState,
        valueChanged: @escaping (String) -> Void
    ) {
        self.theme = theme
        self.placeholder = placeholder
        self.externalState = externalState
        self.valueChanged = valueChanged
    }

    static func ==(lhs: SearchItemComponent, rhs: SearchItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        return true
    }

    final class View: UIView, UITextFieldDelegate {
        private let icon = ComponentView<Empty>()
        private let textField: UITextField
        private let clearButton = ComponentView<Empty>()

        private var component: SearchItemComponent?

        override init(frame: CGRect) {
            self.textField = UITextField()
            super.init(frame: frame)

            self.textField.autocorrectionType = .no
            self.textField.autocapitalizationType = .none
            self.textField.returnKeyType = .search
            self.textField.delegate = self
            self.textField.addTarget(self, action: #selector(self.textFieldChanged(_:)), for: .editingChanged)
            self.addSubview(self.textField)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func textFieldChanged(_ textField: UITextField) {
            self.component?.valueChanged(textField.text ?? "")
            self.updateClearButton()
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            self.component?.externalState.isEditing = true
            self.component?.valueChanged(textField.text ?? "")
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            self.component?.externalState.isEditing = false
            self.component?.valueChanged(textField.text ?? "")
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }

        private func updateClearButton() {
            if let clearView = self.clearButton.view {
                clearView.isHidden = (self.textField.text ?? "").isEmpty
            }
        }

        func update(component: SearchItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component

            let size = CGSize(width: availableSize.width, height: 42.0)

            // Search icon
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: "Chat/Context Menu/Search",
                    tintColor: component.theme.contextMenu.primaryColor
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let iconFrame = CGRect(origin: CGPoint(x: 23.0, y: floorToScreenPixels((size.height - iconSize.height) * 0.5)), size: iconSize)
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    iconView.isUserInteractionEnabled = false
                    self.addSubview(iconView)
                }
                iconView.frame = iconFrame
            }

            // Text field
            let inputInset: CGFloat = 60.0
            let inputRightInset: CGFloat = 36.0
            self.textField.font = Font.regular(17.0)
            self.textField.textColor = component.theme.contextMenu.primaryColor
            self.textField.attributedPlaceholder = NSAttributedString(
                string: component.placeholder,
                attributes: [
                    .font: Font.regular(17.0),
                    .foregroundColor: component.theme.contextMenu.secondaryColor
                ]
            )
            self.textField.tintColor = component.theme.list.itemAccentColor
            self.textField.keyboardAppearance = component.theme.overallDarkAppearance ? .dark : .light
            self.textField.frame = CGRect(
                x: inputInset,
                y: 0.0,
                width: size.width - inputInset - inputRightInset,
                height: size.height
            )

            // Clear button
            let clearSize = self.clearButton.update(
                transition: .immediate,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(
                            BundleIconComponent(
                                name: "Components/Search Bar/Clear",
                                tintColor: component.theme.contextMenu.secondaryColor,
                                maxSize: CGSize(width: 24.0, height: 24.0)
                            )
                        ),
                        action: { [weak self] in
                            guard let self else { return }
                            self.textField.text = ""
                            self.component?.valueChanged("")
                            self.updateClearButton()
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 30.0, height: 30.0)
            )
            let clearFrame = CGRect(
                origin: CGPoint(
                    x: size.width - clearSize.width - 10.0,
                    y: floorToScreenPixels((size.height - clearSize.height) * 0.5)
                ),
                size: clearSize
            )
            if let clearView = self.clearButton.view {
                if clearView.superview == nil {
                    self.addSubview(clearView)
                }
                clearView.frame = clearFrame
                clearView.isHidden = (self.textField.text ?? "").isEmpty
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
