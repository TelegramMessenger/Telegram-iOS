import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextComponent
import EmojiStatusComponent
import Postbox
import Markdown
import ContextUI
import AnimatedAvatarSetNode
import AvatarNode

private extension StorageUsageScreenComponent.Category {
    init(_ category: StorageUsageStats.CategoryKey) {
        switch category {
        case .photos:
            self = .photos
        case .videos:
            self = .videos
        case .files:
            self = .files
        case .music:
            self = .music
        case .stickers:
            self = .stickers
        case .avatars:
            self = .avatars
        case .misc:
            self = .misc
        }
    }
}

final class StorageUsageScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let makeStorageUsageExceptionsScreen: (CacheStorageSettings.PeerStorageCategory) -> ViewController?
    let peer: EnginePeer?
    
    init(
        context: AccountContext,
        makeStorageUsageExceptionsScreen: @escaping (CacheStorageSettings.PeerStorageCategory) -> ViewController?,
        peer: EnginePeer?
    ) {
        self.context = context
        self.makeStorageUsageExceptionsScreen = makeStorageUsageExceptionsScreen
        self.peer = peer
    }
    
    static func ==(lhs: StorageUsageScreenComponent, rhs: StorageUsageScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        return true
    }
    
    private final class ScrollViewImpl: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
        
        override var contentOffset: CGPoint {
            set(value) {
                var value = value
                if value.y > self.contentSize.height - self.bounds.height {
                    value.y = max(0.0, self.contentSize.height - self.bounds.height)
                    self.bounces = false
                } else {
                    self.bounces = true
                }
                super.contentOffset = value
            } get {
                return super.contentOffset
            }
        }
    }
    
    private final class AnimationHint {
        enum Value {
            case firstStatsUpdate
            case clearedItems
        }
        let value: Value
        
        init(value: Value) {
            self.value = value
        }
    }
    
    final class SelectionState: Equatable {
        let selectedPeers: Set<EnginePeer.Id>
        let selectedMessages: Set<EngineMessage.Id>
        
        init(
            selectedPeers: Set<EnginePeer.Id>,
            selectedMessages: Set<EngineMessage.Id>
        ) {
            self.selectedPeers = selectedPeers
            self.selectedMessages = selectedMessages
        }
        
        static func ==(lhs: SelectionState, rhs: SelectionState) -> Bool {
            if lhs.selectedPeers != rhs.selectedPeers {
                return false
            }
            if lhs.selectedMessages != rhs.selectedMessages {
                return false
            }
            return true
        }
        
        func togglePeer(id: EnginePeer.Id) -> SelectionState {
            var selectedPeers = self.selectedPeers
            if selectedPeers.contains(id) {
                selectedPeers.remove(id)
            } else {
                selectedPeers.insert(id)
            }
            
            return SelectionState(
                selectedPeers: selectedPeers,
                selectedMessages: Set()
            )
        }
        
        func toggleMessage(id: EngineMessage.Id) -> SelectionState {
            var selectedMessages = self.selectedMessages
            if selectedMessages.contains(id) {
                selectedMessages.remove(id)
            } else {
                selectedMessages.insert(id)
            }
            
            return SelectionState(
                selectedPeers: Set(),
                selectedMessages: selectedMessages
            )
        }
    }
    
    enum Category: Hashable {
        case photos
        case videos
        case files
        case music
        case other
        case stickers
        case avatars
        case misc
        
        var color: UIColor {
            switch self {
            case .photos:
                return UIColor(rgb: 0x5AC8FA)
            case .videos:
                return UIColor(rgb: 0x3478F6)
            case .files:
                return UIColor(rgb: 0x34C759)
            case .music:
                return UIColor(rgb: 0xFF2D55)
            case .other:
                return UIColor(rgb: 0xC4C4C6)
            case .stickers:
                return UIColor(rgb: 0x5856D6)
            case .avatars:
                return UIColor(rgb: 0xAF52DE)
            case .misc:
                return UIColor(rgb: 0xFF9500)
            }
        }
        
        func title(strings: PresentationStrings) -> String {
            switch self {
            case .photos:
                return "Photos"
            case .videos:
                return "Videos"
            case .files:
                return "Files"
            case .music:
                return "Music"
            case .other:
                return "Other"
            case .stickers:
                return "Stickers"
            case .avatars:
                return "Avatars"
            case .misc:
                return "Miscellaneous"
            }
        }
    }
    
    class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollViewImpl
        
        private var currentStats: AllStorageUsageStats?
        private var currentMessages: [MessageId: Message] = [:]
        private var cacheSettings: CacheStorageSettings?
        private var peerItems: StoragePeerListPanelComponent.Items?
        private var imageItems: StorageFileListPanelComponent.Items?
        private var fileItems: StorageFileListPanelComponent.Items?
        private var musicItems: StorageFileListPanelComponent.Items?
        
        private var selectionState: SelectionState?
        
        private var selectedCategories: Set<Category> = Set()
        private var isOtherCategoryExpanded: Bool = false
        
        private let navigationBackgroundView: BlurredBackgroundView
        private let navigationSeparatorLayer: SimpleLayer
        private let navigationEditButton = ComponentView<Empty>()
        private let navigationDoneButton = ComponentView<Empty>()
        
        private let headerView = ComponentView<Empty>()
        private let headerOffsetContainer: UIView
        private let headerDescriptionView = ComponentView<Empty>()
        
        private let headerProgressBackgroundLayer: SimpleLayer
        private let headerProgressForegroundLayer: SimpleLayer
        
        private var chartAvatarNode: AvatarNode?
        
        private let pieChartView = ComponentView<Empty>()
        private let chartTotalLabel = ComponentView<Empty>()
        private let categoriesView = ComponentView<Empty>()
        private let categoriesDescriptionView = ComponentView<Empty>()
        
        private let keepDurationTitleView = ComponentView<Empty>()
        private let keepDurationDescriptionView = ComponentView<Empty>()
        private var keepDurationSectionContainerView: UIView
        private var keepDurationItems: [AnyHashable: ComponentView<Empty>] = [:]
        
        private let panelContainer = ComponentView<StorageUsagePanelContainerEnvironment>()
        
        private var selectionPanel: ComponentView<Empty>?
        
        private var component: StorageUsageScreenComponent?
        private weak var state: EmptyComponentState?
        private var navigationMetrics: (navigationHeight: CGFloat, statusBarHeight: CGFloat)?
        private var controller: (() -> ViewController?)?
        
        private var enableVelocityTracking: Bool = false
        private var previousVelocityM1: CGFloat = 0.0
        private var previousVelocity: CGFloat = 0.0
        
        private var ignoreScrolling: Bool = false
        
        private var statsDisposable: Disposable?
        private var messagesDisposable: Disposable?
        private var cacheSettingsDisposable: Disposable?
        
        override init(frame: CGRect) {
            self.headerOffsetContainer = UIView()
            self.headerOffsetContainer.isUserInteractionEnabled = false
            
            self.navigationBackgroundView = BlurredBackgroundView(color: nil, enableBlur: true)
            self.navigationSeparatorLayer = SimpleLayer()
            
            self.scrollView = ScrollViewImpl()
            
            self.keepDurationSectionContainerView = UIView()
            self.keepDurationSectionContainerView.clipsToBounds = true
            self.keepDurationSectionContainerView.layer.cornerRadius = 10.0
            
            self.headerProgressBackgroundLayer = SimpleLayer()
            self.headerProgressForegroundLayer = SimpleLayer()
            
            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            self.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.keepDurationSectionContainerView)
            
            self.scrollView.layer.addSublayer(self.headerProgressBackgroundLayer)
            self.scrollView.layer.addSublayer(self.headerProgressForegroundLayer)
            
            self.addSubview(self.navigationBackgroundView)
            self.layer.addSublayer(self.navigationSeparatorLayer)
            
            self.addSubview(self.headerOffsetContainer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.statsDisposable?.dispose()
            self.messagesDisposable?.dispose()
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            self.enableVelocityTracking = true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                if self.enableVelocityTracking {
                    self.previousVelocityM1 = self.previousVelocity
                    if let value = (scrollView.value(forKey: (["_", "verticalVelocity"] as [String]).joined()) as? NSNumber)?.doubleValue {
                        self.previousVelocity = CGFloat(value)
                    }
                }
                
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            guard let navigationMetrics = self.navigationMetrics else {
                return
            }
            let _ = navigationMetrics
            
            let paneAreaExpansionDistance: CGFloat = 32.0
            let paneAreaExpansionFinalPoint: CGFloat = scrollView.contentSize.height - scrollView.bounds.height
            if targetContentOffset.pointee.y > paneAreaExpansionFinalPoint - paneAreaExpansionDistance && targetContentOffset.pointee.y < paneAreaExpansionFinalPoint {
                targetContentOffset.pointee.y = paneAreaExpansionFinalPoint
                self.enableVelocityTracking = false
                self.previousVelocity = 0.0
                self.previousVelocityM1 = 0.0
            }
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            if let panelContainerView = self.panelContainer.view as? StorageUsagePanelContainerComponent.View {
                let _ = panelContainerView
                let paneAreaExpansionFinalPoint: CGFloat = scrollView.contentSize.height - scrollView.bounds.height
                if abs(scrollView.contentOffset.y - paneAreaExpansionFinalPoint) < .ulpOfOne {
                    //panelContainerView.transferVelocity(self.previousVelocityM1)
                }
            }
        }
        
        private func updateScrolling(transition: Transition) {
            let scrollBounds = self.scrollView.bounds
            
            let isLockedAtPanels = scrollBounds.maxY == self.scrollView.contentSize.height
            
            if let headerView = self.headerView.view, let navigationMetrics = self.navigationMetrics {
                var headerOffset: CGFloat = scrollBounds.minY
                
                let minY = navigationMetrics.statusBarHeight + floor((navigationMetrics.navigationHeight - navigationMetrics.statusBarHeight) / 2.0)
                
                let minOffset = headerView.center.y - minY
                
                headerOffset = min(headerOffset, minOffset)
                
                let animatedTransition = Transition(animation: .curve(duration: 0.18, curve: .easeInOut))
                let navigationBackgroundAlpha: CGFloat = abs(headerOffset - minOffset) < 4.0 ? 1.0 : 0.0
                
                animatedTransition.setAlpha(view: self.navigationBackgroundView, alpha: navigationBackgroundAlpha)
                
                if let navigationEditButtonView = self.navigationEditButton.view {
                    animatedTransition.setAlpha(view: navigationEditButtonView, alpha: (self.selectionState == nil ? 1.0 : 0.0) * navigationBackgroundAlpha)
                }
                if let navigationDoneButtonView = self.navigationDoneButton.view {
                    animatedTransition.setAlpha(view: navigationDoneButtonView, alpha: (self.selectionState == nil ? 0.0 : 1.0) * navigationBackgroundAlpha)
                }
                
                if abs(headerOffset - minOffset) < 4.0 && !isLockedAtPanels {
                    animatedTransition.setAlpha(layer: self.navigationSeparatorLayer, alpha: 1.0)
                } else {
                    animatedTransition.setAlpha(layer: self.navigationSeparatorLayer, alpha: 0.0)
                }
                
                var offsetFraction: CGFloat = abs(headerOffset - minOffset) / 60.0
                offsetFraction = min(1.0, max(0.0, offsetFraction))
                transition.setScale(view: headerView, scale: 1.0 * offsetFraction + 0.8 * (1.0 - offsetFraction))
                
                transition.setBounds(view: self.headerOffsetContainer, bounds: CGRect(origin: CGPoint(x: 0.0, y: headerOffset), size: self.headerOffsetContainer.bounds.size))
            }
            
            let _ = self.panelContainer.updateEnvironment(
                transition: transition,
                environment: {
                    StorageUsagePanelContainerEnvironment(isScrollable: isLockedAtPanels)
                }
            )
        }
        
        func update(component: StorageUsageScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            
            if self.statsDisposable == nil {
                self.cacheSettingsDisposable = (component.context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.cacheStorageSettings])
                |> map { sharedData -> CacheStorageSettings in
                    let cacheSettings: CacheStorageSettings
                    if let value = sharedData.entries[SharedDataKeys.cacheStorageSettings]?.get(CacheStorageSettings.self) {
                        cacheSettings = value
                    } else {
                        cacheSettings = CacheStorageSettings.defaultSettings
                    }
                    
                    return cacheSettings
                }
                |> deliverOnMainQueue).start(next: { [weak self] cacheSettings in
                    guard let self else {
                        return
                    }
                    self.cacheSettings = cacheSettings
                    if self.currentStats != nil {
                        self.state?.updated(transition: .immediate)
                    }
                })
                
                self.reloadStats(firstTime: true)
            }
            
            var wasLockedAtPanels = false
            if let panelContainerView = self.panelContainer.view, let navigationMetrics = self.navigationMetrics {
                if self.scrollView.bounds.minY > 0.0 && abs(self.scrollView.bounds.minY - (panelContainerView.frame.minY - navigationMetrics.navigationHeight)) <= UIScreenPixel {
                    wasLockedAtPanels = true
                }
            }
            
            let animationHint = transition.userData(AnimationHint.self)
            
            if let animationHint, case .firstStatsUpdate = animationHint.value {
                var alphaTransition = transition
                if case .firstStatsUpdate = animationHint.value {
                    alphaTransition = .easeInOut(duration: 0.25)
                }
                alphaTransition.setAlpha(view: self.scrollView, alpha: self.currentStats != nil ? 1.0 : 0.0)
                alphaTransition.setAlpha(view: self.headerOffsetContainer, alpha: self.currentStats != nil ? 1.0 : 0.0)
            } else {
                transition.setAlpha(view: self.scrollView, alpha: self.currentStats != nil ? 1.0 : 0.0)
                transition.setAlpha(view: self.headerOffsetContainer, alpha: self.currentStats != nil ? 1.0 : 0.0)
            }
            
            self.controller = environment.controller
            
            self.navigationMetrics = (environment.navigationHeight, environment.statusBarHeight)
            
            self.navigationSeparatorLayer.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
            
            let navigationFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: environment.navigationHeight))
            self.navigationBackgroundView.updateColor(color: environment.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
            self.navigationBackgroundView.update(size: navigationFrame.size, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.navigationBackgroundView, frame: navigationFrame)
            transition.setFrame(layer: self.navigationSeparatorLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationFrame.maxY), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            
            let navigationEditButtonSize = self.navigationEditButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Text(text: environment.strings.Common_Edit, font: Font.regular(17.0), color: environment.theme.rootController.navigationBar.accentTextColor)),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        if self.selectionState == nil {
                            self.selectionState = SelectionState(
                                selectedPeers: Set(),
                                selectedMessages: Set()
                            )
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                        }
                    }
                ).minSize(CGSize(width: 16.0, height: environment.navigationHeight - environment.statusBarHeight))),
                environment: {},
                containerSize: CGSize(width: 150.0, height: environment.navigationHeight - environment.statusBarHeight)
            )
            if let navigationEditButtonView = self.navigationEditButton.view {
                if navigationEditButtonView.superview == nil {
                    self.addSubview(navigationEditButtonView)
                }
                transition.setFrame(view: navigationEditButtonView, frame: CGRect(origin: CGPoint(x: availableSize.width - 12.0 - navigationEditButtonSize.width, y: environment.statusBarHeight), size: navigationEditButtonSize))
            }
            
            let navigationDoneButtonSize = self.navigationDoneButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Text(text: environment.strings.Common_Done, font: Font.semibold(17.0), color: environment.theme.rootController.navigationBar.accentTextColor)),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.selectionState = nil
                        self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                    }
                ).minSize(CGSize(width: 16.0, height: environment.navigationHeight - environment.statusBarHeight))),
                environment: {},
                containerSize: CGSize(width: 150.0, height: environment.navigationHeight - environment.statusBarHeight)
            )
            if let navigationDoneButtonView = self.navigationDoneButton.view {
                if navigationDoneButtonView.superview == nil {
                    self.addSubview(navigationDoneButtonView)
                }
                transition.setFrame(view: navigationDoneButtonView, frame: CGRect(origin: CGPoint(x: availableSize.width - 12.0 - navigationDoneButtonSize.width, y: environment.statusBarHeight), size: navigationDoneButtonSize))
            }
            
            let navigationRightButtonMaxWidth: CGFloat = max(navigationEditButtonSize.width, navigationDoneButtonSize.width)
            
            self.backgroundColor = environment.theme.list.blocksBackgroundColor
            
            var contentHeight: CGFloat = 0.0
            
            let topInset: CGFloat = 19.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            var bottomInset: CGFloat = environment.safeInsets.bottom
            if let selectionState = self.selectionState {
                let selectionPanel: ComponentView<Empty>
                var selectionPanelTransition = transition
                if let current = self.selectionPanel {
                    selectionPanel = current
                } else {
                    selectionPanelTransition = .immediate
                    selectionPanel = ComponentView()
                    self.selectionPanel = selectionPanel
                }
                
                var selectedSize: Int64 = 0
                if let currentStats = self.currentStats {
                    for peerId in selectionState.selectedPeers {
                        if let stats = currentStats.peers[peerId] {
                            let peerSize = stats.stats.categories.values.reduce(0, {
                                $0 + $1.size
                            })
                            selectedSize += peerSize
                        }
                    }
                    
                    let contextStats: StorageUsageStats
                    if let peer = component.peer {
                        contextStats = currentStats.peers[peer.id]?.stats ?? StorageUsageStats(categories: [:])
                    } else {
                        contextStats = currentStats.totalStats
                    }
                    
                    for messageId in selectionState.selectedMessages {
                        for (_, category) in contextStats.categories {
                            if let messageSize = category.messages[messageId] {
                                selectedSize += messageSize
                                break
                            }
                        }
                    }
                }
                
                //TODO:localize
                let selectionPanelSize = selectionPanel.update(
                    transition: selectionPanelTransition,
                    component: AnyComponent(StorageUsageScreenSelectionPanelComponent(
                        theme: environment.theme,
                        title: "Clear Selected",
                        label: selectedSize == 0 ? nil : dataSizeString(Int(selectedSize), formatting: DataSizeStringFormatting(strings: environment.strings, decimalSeparator: ".")),
                        isEnabled: selectedSize != 0,
                        insets: UIEdgeInsets(top: 0.0, left: sideInset, bottom: environment.safeInsets.bottom, right: sideInset),
                        action: { [weak self] in
                            guard let self, let selectionState = self.selectionState else {
                                return
                            }
                            self.requestClear(categories: Set(), peers: selectionState.selectedPeers, messages: selectionState.selectedMessages)
                        }
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                if let selectionPanelView = selectionPanel.view {
                    var animateIn = false
                    if selectionPanelView.superview == nil {
                        self.addSubview(selectionPanelView)
                        animateIn = true
                    }
                    selectionPanelTransition.setFrame(view: selectionPanelView, frame: CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - selectionPanelSize.height), size: selectionPanelSize))
                    if animateIn {
                        transition.animatePosition(view: selectionPanelView, from: CGPoint(x: 0.0, y: selectionPanelSize.height), to: CGPoint(), additive: true)
                    }
                }
                bottomInset = selectionPanelSize.height
            } else if let selectionPanel = self.selectionPanel {
                self.selectionPanel = nil
                if let selectionPanelView = selectionPanel.view {
                    transition.setPosition(view: selectionPanelView, position: CGPoint(x: selectionPanelView.center.x, y: availableSize.height + selectionPanelView.bounds.height * 0.5), completion: { [weak selectionPanelView] _ in
                        selectionPanelView?.removeFromSuperview()
                    })
                }
            }
            
            contentHeight += environment.statusBarHeight + topInset
            
            let chartOrder: [Category] = [
                .photos,
                .videos,
                .files,
                .music,
                .stickers,
                .avatars,
                .misc
            ]
            
            if let animationHint, case .firstStatsUpdate = animationHint.value, let currentStats = self.currentStats {
                let contextStats: StorageUsageStats
                if let peer = component.peer {
                    contextStats = currentStats.peers[peer.id]?.stats ?? StorageUsageStats(categories: [:])
                } else {
                    contextStats = currentStats.totalStats
                }
                
                for (category, value) in contextStats.categories {
                    if value.size != 0 {
                        self.selectedCategories.insert(StorageUsageScreenComponent.Category(category))
                    }
                }
            }
            
            var chartItems: [PieChartComponent.ChartData.Item] = []
            var listCategories: [StorageCategoriesComponent.CategoryData] = []
            
            let otherCategories: [Category] = [
                .stickers,
                .avatars,
                .misc
            ]
            
            var totalSize: Int64 = 0
            if let currentStats = self.currentStats {
                let contextStats: StorageUsageStats
                if let peer = component.peer {
                    contextStats = currentStats.peers[peer.id]?.stats ?? StorageUsageStats(categories: [:])
                } else {
                    contextStats = currentStats.totalStats
                }
                
                for (_, value) in contextStats.categories {
                    totalSize += value.size
                }
                
                for category in chartOrder {
                    let mappedCategory: StorageUsageStats.CategoryKey
                    switch category {
                    case .photos:
                        mappedCategory = .photos
                    case .videos:
                        mappedCategory = .videos
                    case .files:
                        mappedCategory = .files
                    case .music:
                        mappedCategory = .music
                    case .stickers:
                        mappedCategory = .stickers
                    case .avatars:
                        mappedCategory = .avatars
                    case .misc:
                        mappedCategory = .misc
                    case .other:
                        continue
                    }
                    
                    var categorySize: Int64 = 0
                    if let categoryData = contextStats.categories[mappedCategory] {
                        categorySize = categoryData.size
                    }
                    
                    let categoryFraction: Double
                    if categorySize == 0 || totalSize == 0 {
                        categoryFraction = 0.0
                    } else {
                        categoryFraction = Double(categorySize) / Double(totalSize)
                    }
                    
                    var categoryChartFraction: CGFloat = categoryFraction
                    if !self.selectedCategories.isEmpty && !self.selectedCategories.contains(category) {
                        categoryChartFraction = 0.0
                    }
                    
                    var chartCategoryColor = category.color
                    if !self.isOtherCategoryExpanded && otherCategories.contains(category) {
                        chartCategoryColor = Category.other.color
                    }
                    
                    chartItems.append(PieChartComponent.ChartData.Item(id: category, displayValue: categoryFraction, value: categoryChartFraction, color: chartCategoryColor))
                    
                    if categorySize != 0 {
                        listCategories.append(StorageCategoriesComponent.CategoryData(
                            key: category, color: category.color, title: category.title(strings: environment.strings), size: categorySize, sizeFraction: categoryFraction, isSelected: self.selectedCategories.contains(category), subcategories: []))
                    }
                }
            }
            
            var otherListCategories: [StorageCategoriesComponent.CategoryData] = []
            for listCategory in listCategories {
                if otherCategories.contains(where: { $0 == listCategory.key }) {
                    otherListCategories.append(listCategory)
                }
            }
            listCategories = listCategories.filter { item in
                return !otherCategories.contains(where: { $0 == item.key })
            }
            if !otherListCategories.isEmpty {
                var totalOtherSize: Int64 = 0
                for listCategory in otherListCategories {
                    totalOtherSize += listCategory.size
                }
                let categoryFraction: Double
                if totalOtherSize == 0 || totalSize == 0 {
                    categoryFraction = 0.0
                } else {
                    categoryFraction = Double(totalOtherSize) / Double(totalSize)
                }
                let isSelected = otherListCategories.allSatisfy { item in
                    return self.selectedCategories.contains(item.key)
                }
                listCategories.append(StorageCategoriesComponent.CategoryData(
                    key: Category.other, color: Category.other.color, title: Category.other.title(strings: environment.strings), size: totalOtherSize, sizeFraction: categoryFraction, isSelected: isSelected, subcategories: otherListCategories))
            }
            
            let chartData = PieChartComponent.ChartData(items: chartItems)
            self.pieChartView.parentState = state
            let pieChartSize = self.pieChartView.update(
                transition: transition,
                component: AnyComponent(PieChartComponent(
                    theme: environment.theme,
                    chartData: chartData
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 60.0)
            )
            let pieChartFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: pieChartSize)
            if let pieChartComponentView = self.pieChartView.view {
                if pieChartComponentView.superview == nil {
                    self.scrollView.addSubview(pieChartComponentView)
                }
                
                transition.setFrame(view: pieChartComponentView, frame: pieChartFrame)
            }
            contentHeight += pieChartSize.height
            contentHeight += 26.0
            
            let headerViewSize = self.headerView.update(
                transition: transition,
                component: AnyComponent(Text(text: "Storage Usage", font: Font.semibold(22.0), color: environment.theme.list.itemPrimaryTextColor)),
                environment: {},
                containerSize: CGSize(width: floor((availableSize.width - navigationRightButtonMaxWidth * 2.0) / 0.8), height: 100.0)
            )
            let headerViewFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - headerViewSize.width) / 2.0), y: contentHeight), size: headerViewSize)
            if let headerComponentView = self.headerView.view {
                if headerComponentView.superview == nil {
                    self.headerOffsetContainer.addSubview(headerComponentView)
                }
                transition.setPosition(view: headerComponentView, position: headerViewFrame.center)
                transition.setBounds(view: headerComponentView, bounds: CGRect(origin: CGPoint(), size: headerViewFrame.size))
            }
            contentHeight += headerViewSize.height
            
            contentHeight += 4.0
            
            let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.freeTextColor)
            let bold = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.freeTextColor)
            
            //TODO:localize
            let headerDescriptionSize = self.headerDescriptionView.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(text: .markdown(text: "Telegram users 9.7% of your free disk space.", attributes: MarkdownAttributes(
                    body: body,
                    bold: bold,
                    link: body,
                    linkAttribute: { _ in nil }
                )), maximumNumberOfLines: 0)),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 15.0 * 2.0, height: 10000.0)
            )
            let headerDescriptionFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - headerDescriptionSize.width) / 2.0), y: contentHeight), size: headerDescriptionSize)
            if let headerDescriptionComponentView = self.headerDescriptionView.view {
                if headerDescriptionComponentView.superview == nil {
                    self.scrollView.addSubview(headerDescriptionComponentView)
                }
                transition.setFrame(view: headerDescriptionComponentView, frame: headerDescriptionFrame)
            }
            contentHeight += headerDescriptionSize.height
            contentHeight += 8.0
            
            let headerProgressWidth: CGFloat = min(200.0, availableSize.width - sideInset * 2.0)
            let headerProgressFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - headerProgressWidth) / 2.0), y: contentHeight), size: CGSize(width: headerProgressWidth, height: 4.0))
            transition.setFrame(layer: self.headerProgressBackgroundLayer, frame: headerProgressFrame)
            transition.setCornerRadius(layer: self.headerProgressBackgroundLayer, cornerRadius: headerProgressFrame.height * 0.5)
            self.headerProgressBackgroundLayer.backgroundColor = environment.theme.list.itemAccentColor.withMultipliedAlpha(0.2).cgColor
            
            let headerProgress: CGFloat = 0.097
            transition.setFrame(layer: self.headerProgressForegroundLayer, frame: CGRect(origin: headerProgressFrame.origin, size: CGSize(width: floorToScreenPixels(headerProgress * headerProgressFrame.width), height: headerProgressFrame.height)))
            transition.setCornerRadius(layer: self.headerProgressForegroundLayer, cornerRadius: headerProgressFrame.height * 0.5)
            self.headerProgressForegroundLayer.backgroundColor = environment.theme.list.itemAccentColor.cgColor
            contentHeight += 4.0
            
            contentHeight += 24.0
            
            if let peer = component.peer {
                let avatarSize = CGSize(width: 72.0, height: 72.0)
                let avatarFrame: CGRect = CGRect(origin: CGPoint(x: pieChartFrame.minX + floor((pieChartFrame.width - avatarSize.width) / 2.0), y: pieChartFrame.minY + floor((pieChartFrame.height - avatarSize.height) / 2.0)), size: avatarSize)
                
                let chartAvatarNode: AvatarNode
                if let current = self.chartAvatarNode {
                    chartAvatarNode = current
                    transition.setFrame(view: chartAvatarNode.view, frame: avatarFrame)
                } else {
                    chartAvatarNode = AvatarNode(font: avatarPlaceholderFont(size: 17.0))
                    self.chartAvatarNode = chartAvatarNode
                    self.scrollView.addSubview(chartAvatarNode.view)
                    chartAvatarNode.frame = avatarFrame
                    
                    chartAvatarNode.setPeer(context: component.context, theme: environment.theme, peer: peer, displayDimensions: avatarSize)
                }
            } else {
                let chartTotalLabelSize = self.chartTotalLabel.update(
                    transition: transition,
                    component: AnyComponent(Text(text: dataSizeString(Int(totalSize), formatting: DataSizeStringFormatting(strings: environment.strings, decimalSeparator: ".")), font: Font.with(size: 20.0, design: .round, weight: .bold), color: environment.theme.list.itemPrimaryTextColor)), environment: {}, containerSize: CGSize(width: 200.0, height: 200.0)
                )
                if let chartTotalLabelView = self.chartTotalLabel.view {
                    if chartTotalLabelView.superview == nil {
                        self.scrollView.addSubview(chartTotalLabelView)
                    }
                    transition.setFrame(view: chartTotalLabelView, frame: CGRect(origin: CGPoint(x: pieChartFrame.minX + floor((pieChartFrame.width - chartTotalLabelSize.width) / 2.0), y: pieChartFrame.minY + floor((pieChartFrame.height - chartTotalLabelSize.height) / 2.0)), size: chartTotalLabelSize))
                }
            }
            
            if !listCategories.isEmpty {
                self.categoriesView.parentState = state
                let categoriesSize = self.categoriesView.update(
                    transition: transition,
                    component: AnyComponent(StorageCategoriesComponent(
                        theme: environment.theme,
                        strings: environment.strings,
                        categories: listCategories,
                        isOtherExpanded: self.isOtherCategoryExpanded,
                        toggleCategorySelection: { [weak self] key in
                            guard let self else {
                                return
                            }
                            if key == Category.other {
                                let otherCategories: [Category] = [.stickers, .avatars, .misc]
                                if otherCategories.allSatisfy(self.selectedCategories.contains) {
                                    for item in otherCategories {
                                        self.selectedCategories.remove(item)
                                    }
                                    self.selectedCategories.remove(Category.other)
                                } else {
                                    for item in otherCategories {
                                        let _ = self.selectedCategories.insert(item)
                                    }
                                    let _ = self.selectedCategories.insert(Category.other)
                                }
                            } else {
                                if self.selectedCategories.contains(key) {
                                    self.selectedCategories.remove(key)
                                } else {
                                    self.selectedCategories.insert(key)
                                }
                            }
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                        },
                        toggleOtherExpanded: { [weak self] in
                            guard let self else {
                                return
                            }
                            
                            self.isOtherCategoryExpanded = !self.isOtherCategoryExpanded
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                        },
                        clearAction: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.requestClear(categories: self.selectedCategories, peers: Set(), messages: Set())
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude)
                )
                if let categoriesComponentView = self.categoriesView.view {
                    if categoriesComponentView.superview == nil {
                        self.scrollView.addSubview(categoriesComponentView)
                    }
                    
                    transition.setFrame(view: categoriesComponentView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: categoriesSize))
                }
                contentHeight += categoriesSize.height
                contentHeight += 8.0
                
                
                //TODO:localize
                let categoriesDescriptionSize = self.categoriesDescriptionView.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(text: .markdown(text: "All media will stay in the Telegram cloud and can be re-downloaded if you need it again.", attributes: MarkdownAttributes(
                        body: body,
                        bold: bold,
                        link: body,
                        linkAttribute: { _ in nil }
                    )), maximumNumberOfLines: 0)),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 15.0 * 2.0, height: 10000.0)
                )
                let categoriesDescriptionFrame = CGRect(origin: CGPoint(x: sideInset + 15.0, y: contentHeight), size: categoriesDescriptionSize)
                if let categoriesDescriptionComponentView = self.categoriesDescriptionView.view {
                    if categoriesDescriptionComponentView.superview == nil {
                        self.scrollView.addSubview(categoriesDescriptionComponentView)
                    }
                    transition.setFrame(view: categoriesDescriptionComponentView, frame: categoriesDescriptionFrame)
                }
                contentHeight += categoriesDescriptionSize.height
                contentHeight += 40.0
            } else {
                self.categoriesView.view?.removeFromSuperview()
                self.categoriesDescriptionView.view?.removeFromSuperview()
            }
            
            if component.peer == nil {
                //TODO:localize
                let keepDurationTitleSize = self.keepDurationTitleView.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .markdown(
                            text: "KEEP MEDIA", attributes: MarkdownAttributes(
                                body: body,
                                bold: bold,
                                link: body,
                                linkAttribute: { _ in nil }
                            )
                        ),
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 15.0 * 2.0, height: 10000.0)
                )
                let keepDurationTitleFrame = CGRect(origin: CGPoint(x: sideInset + 15.0, y: contentHeight), size: keepDurationTitleSize)
                if let keepDurationTitleComponentView = self.keepDurationTitleView.view {
                    if keepDurationTitleComponentView.superview == nil {
                        self.scrollView.addSubview(keepDurationTitleComponentView)
                    }
                    transition.setFrame(view: keepDurationTitleComponentView, frame: keepDurationTitleFrame)
                }
                contentHeight += keepDurationTitleSize.height
                contentHeight += 8.0
                
                
                var keepContentHeight: CGFloat = 0.0
                for i in 0 ..< 3 {
                    let item: ComponentView<Empty>
                    if let current = self.keepDurationItems[i] {
                        item = current
                    } else {
                        item = ComponentView<Empty>()
                        self.keepDurationItems[i] = item
                    }
                    
                    let mappedCategory: CacheStorageSettings.PeerStorageCategory
                    
                    //TODO:localize
                    let iconName: String
                    let title: String
                    switch i {
                    case 0:
                        iconName = "Settings/Menu/EditProfile"
                        title = "Private Chats"
                        mappedCategory = .privateChats
                    case 1:
                        iconName = "Settings/Menu/GroupChats"
                        title = "Group Chats"
                        mappedCategory = .groups
                    default:
                        iconName = "Settings/Menu/Channels"
                        title = "Channels"
                        mappedCategory = .channels
                    }
                    
                    let value = self.cacheSettings?.categoryStorageTimeout[mappedCategory] ?? Int32.max
                    let optionText: String
                    if value == Int32.max {
                        optionText = environment.strings.ClearCache_Forever
                    } else {
                        optionText = timeIntervalString(strings: environment.strings, value: value)
                    }
                    
                    let itemSize = item.update(
                        transition: transition,
                        component: AnyComponent(StoragePeerTypeItemComponent(
                            theme: environment.theme,
                            iconName: iconName,
                            title: title,
                            value: optionText,
                            hasNext: i != 3 - 1,
                            action: { [weak self] sourceView in
                                guard let self else {
                                    return
                                }
                                self.openKeepMediaCategory(mappedCategory: mappedCategory, sourceView: sourceView)
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                    )
                    let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: keepContentHeight), size: itemSize)
                    if let itemView = item.view {
                        if itemView.superview == nil {
                            self.keepDurationSectionContainerView.addSubview(itemView)
                        }
                        transition.setFrame(view: itemView, frame: itemFrame)
                    }
                    keepContentHeight += itemSize.height
                }
                self.keepDurationSectionContainerView.backgroundColor = environment.theme.list.itemBlocksBackgroundColor
                transition.setFrame(view: self.keepDurationSectionContainerView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset * 2.0, height: keepContentHeight)))
                contentHeight += keepContentHeight
                contentHeight += 8.0
                
                //TODO:localize
                let keepDurationDescriptionSize = self.keepDurationDescriptionView.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .markdown(
                            text: "Photos, videos and other files from cloud chats that you have **not accessed** during this period will be removed from this device to save disk space.", attributes: MarkdownAttributes(
                                body: body,
                                bold: bold,
                                link: body,
                                linkAttribute: { _ in nil }
                            )
                        ),
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 15.0 * 2.0, height: 10000.0)
                )
                let keepDurationDescriptionFrame = CGRect(origin: CGPoint(x: sideInset + 15.0, y: contentHeight), size: keepDurationDescriptionSize)
                if let keepDurationDescriptionComponentView = self.keepDurationDescriptionView.view {
                    if keepDurationDescriptionComponentView.superview == nil {
                        self.scrollView.addSubview(keepDurationDescriptionComponentView)
                    }
                    transition.setFrame(view: keepDurationDescriptionComponentView, frame: keepDurationDescriptionFrame)
                }
                contentHeight += keepDurationDescriptionSize.height
                contentHeight += 40.0
            }
            
            var panelItems: [StorageUsagePanelContainerComponent.Item] = []
            if let peerItems = self.peerItems, !peerItems.items.isEmpty {
                panelItems.append(StorageUsagePanelContainerComponent.Item(
                    id: "peers",
                    title: "Chats",
                    panel: AnyComponent(StoragePeerListPanelComponent(
                        context: component.context,
                        items: self.peerItems,
                        selectionState: self.selectionState,
                        peerAction: { [weak self] peer in
                            guard let self else {
                                return
                            }
                            if let selectionState = self.selectionState {
                                self.selectionState = selectionState.togglePeer(id: peer.id)
                                self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                            } else {
                                self.openPeer(peer: peer)
                            }
                        }
                    ))
                ))
            }
            if let imageItems = self.imageItems, !imageItems.items.isEmpty {
                panelItems.append(StorageUsagePanelContainerComponent.Item(
                    id: "images",
                    title: "Media",
                    panel: AnyComponent(StorageFileListPanelComponent(
                        context: component.context,
                        items: self.imageItems,
                        selectionState: self.selectionState,
                        peerAction: { [weak self] messageId in
                            guard let self else {
                                return
                            }
                            if self.selectionState == nil {
                                self.selectionState = SelectionState(selectedPeers: Set(), selectedMessages: Set())
                            }
                            self.selectionState = self.selectionState?.toggleMessage(id: messageId)
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                        }
                    ))
                ))
            }
            if let fileItems = self.fileItems, !fileItems.items.isEmpty {
                panelItems.append(StorageUsagePanelContainerComponent.Item(
                    id: "files",
                    title: "Files",
                    panel: AnyComponent(StorageFileListPanelComponent(
                        context: component.context,
                        items: self.fileItems,
                        selectionState: self.selectionState,
                        peerAction: { [weak self] messageId in
                            guard let self else {
                                return
                            }
                            if self.selectionState == nil {
                                self.selectionState = SelectionState(selectedPeers: Set(), selectedMessages: Set())
                            }
                            self.selectionState = self.selectionState?.toggleMessage(id: messageId)
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                        }
                    ))
                ))
            }
            if let musicItems = self.musicItems, !musicItems.items.isEmpty {
                panelItems.append(StorageUsagePanelContainerComponent.Item(
                    id: "music",
                    title: "Music",
                    panel: AnyComponent(StorageFileListPanelComponent(
                        context: component.context,
                        items: self.musicItems,
                        selectionState: self.selectionState,
                        peerAction: { [weak self] messageId in
                            guard let self else {
                                return
                            }
                            if self.selectionState == nil {
                                self.selectionState = SelectionState(selectedPeers: Set(), selectedMessages: Set())
                            }
                            self.selectionState = self.selectionState?.toggleMessage(id: messageId)
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                        }
                    ))
                ))
            }
            
            if !panelItems.isEmpty {
                let panelContainerSize = self.panelContainer.update(
                    transition: transition,
                    component: AnyComponent(StorageUsagePanelContainerComponent(
                        theme: environment.theme,
                        strings: environment.strings,
                        dateTimeFormat: environment.dateTimeFormat,
                        insets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left, bottom: bottomInset, right: environment.safeInsets.right),
                        items: panelItems)
                    ),
                    environment: {
                        StorageUsagePanelContainerEnvironment(isScrollable: wasLockedAtPanels)
                    },
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height - environment.navigationHeight)
                )
                if let panelContainerView = self.panelContainer.view {
                    if panelContainerView.superview == nil {
                        self.scrollView.addSubview(panelContainerView)
                    }
                    transition.setFrame(view: panelContainerView, frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: panelContainerSize))
                }
                contentHeight += panelContainerSize.height
            } else {
                self.panelContainer.view?.removeFromSuperview()
            }
            
            self.ignoreScrolling = true
            
            let contentOffset = self.scrollView.bounds.minY
            transition.setPosition(view: self.scrollView, position: CGRect(origin: CGPoint(), size: availableSize).center)
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            
            var scrollViewBounds = self.scrollView.bounds
            scrollViewBounds.size = availableSize
            if wasLockedAtPanels, let panelContainerView = self.panelContainer.view {
                scrollViewBounds.origin.y = panelContainerView.frame.minY - environment.navigationHeight
            }
            transition.setBounds(view: self.scrollView, bounds: scrollViewBounds)
            
            if !wasLockedAtPanels && !transition.animation.isImmediate && self.scrollView.bounds.minY != contentOffset {
                let deltaOffset = self.scrollView.bounds.minY - contentOffset
                transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: -deltaOffset), to: CGPoint(), additive: true)
            }
            
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
        
        private func reloadStats(firstTime: Bool) {
            if let controller = self.controller?() as? StorageUsageScreen {
                controller.reloadParent?()
            }
            
            guard let component = self.component else {
                return
            }
            
            self.statsDisposable = (component.context.engine.resources.collectStorageUsageStats()
            |> deliverOnMainQueue).start(next: { [weak self] stats in
                guard let self, let component = self.component else {
                    return
                }
                self.currentStats = stats
                
                var peerItems: [StoragePeerListPanelComponent.Item] = []
                
                if component.peer == nil {
                    for item in stats.peers.values.sorted(by: { lhs, rhs in
                        let lhsSize: Int64 = lhs.stats.categories.values.reduce(0, {
                            $0 + $1.size
                        })
                        let rhsSize: Int64 = rhs.stats.categories.values.reduce(0, {
                            $0 + $1.size
                        })
                        return lhsSize > rhsSize
                    }) {
                        let itemSize: Int64 = item.stats.categories.values.reduce(0, {
                            $0 + $1.size
                        })
                        peerItems.append(StoragePeerListPanelComponent.Item(
                            peer: item.peer,
                            size: itemSize
                        ))
                    }
                }
                
                self.peerItems = StoragePeerListPanelComponent.Items(items: peerItems)
                
                self.state?.updated(transition: Transition(animation: .none).withUserData(AnimationHint(value: firstTime ? .firstStatsUpdate : .clearedItems)))
                
                class RenderResult {
                    var messages: [MessageId: Message] = [:]
                    var imageItems: [StorageFileListPanelComponent.Item] = []
                    var fileItems: [StorageFileListPanelComponent.Item] = []
                    var musicItems: [StorageFileListPanelComponent.Item] = []
                }
                
                let contextStats: StorageUsageStats
                if let peer = component.peer {
                    contextStats = stats.peers[peer.id]?.stats ?? StorageUsageStats(categories: [:])
                } else {
                    contextStats = stats.totalStats
                }
                
                self.messagesDisposable = (component.context.engine.resources.renderStorageUsageStatsMessages(stats: contextStats, categories: [.files, .photos, .videos, .music], existingMessages: self.currentMessages)
                |> deliverOn(Queue())
                |> map { messages -> RenderResult in
                    let result = RenderResult()
                    
                    result.messages = messages
                    
                    var mergedMedia: [MessageId: Int64] = [:]
                    if let categoryStats = contextStats.categories[.photos] {
                        mergedMedia = categoryStats.messages
                    }
                    if let categoryStats = contextStats.categories[.videos] {
                        for (id, value) in categoryStats.messages {
                            mergedMedia[id] = value
                        }
                    }
                    
                    if !mergedMedia.isEmpty {
                        for (id, messageSize) in mergedMedia.sorted(by: { $0.value > $1.value }) {
                            if let message = messages[id] {
                                var matches = false
                                for media in message.media {
                                    if media is TelegramMediaImage {
                                        matches = true
                                        break
                                    } else if let file = media as? TelegramMediaFile {
                                        if file.isVideo {
                                            matches = true
                                            break
                                        }
                                    }
                                }
                                
                                if matches {
                                    result.imageItems.append(StorageFileListPanelComponent.Item(
                                        message: message,
                                        size: messageSize
                                    ))
                                }
                            }
                        }
                    }
                    
                    if let categoryStats = contextStats.categories[.files] {
                        for (id, messageSize) in categoryStats.messages.sorted(by: { $0.value > $1.value }) {
                            if let message = messages[id] {
                                var matches = false
                                for media in message.media {
                                    if media is TelegramMediaFile {
                                        matches = true
                                    }
                                }
                                
                                if matches {
                                    result.fileItems.append(StorageFileListPanelComponent.Item(
                                        message: message,
                                        size: messageSize
                                    ))
                                }
                            }
                        }
                    }
                    
                    if let categoryStats = contextStats.categories[.music] {
                        for (id, messageSize) in categoryStats.messages.sorted(by: { $0.value > $1.value }) {
                            if let message = messages[id] {
                                var matches = false
                                for media in message.media {
                                    if media is TelegramMediaFile {
                                        matches = true
                                    }
                                }
                                
                                if matches {
                                    result.musicItems.append(StorageFileListPanelComponent.Item(
                                        message: message,
                                        size: messageSize
                                    ))
                                }
                            }
                        }
                    }
                    
                    return result
                }
                |> deliverOnMainQueue).start(next: { [weak self] result in
                    guard let self else {
                        return
                    }
                    
                    self.currentMessages = result.messages
                    
                    self.imageItems = StorageFileListPanelComponent.Items(items: result.imageItems)
                    self.fileItems = StorageFileListPanelComponent.Items(items: result.fileItems)
                    self.musicItems = StorageFileListPanelComponent.Items(items: result.musicItems)
                    
                    self.state?.updated(transition: Transition(animation: .none))
                })
            })
        }
        
        private func openPeer(peer: EnginePeer) {
            guard let component = self.component else {
                return
            }
            guard let controller = self.controller?() else {
                return
            }
            
            let childController = StorageUsageScreen(context: component.context, makeStorageUsageExceptionsScreen: component.makeStorageUsageExceptionsScreen, peer: peer)
            childController.reloadParent = { [weak self] in
                guard let self else {
                    return
                }
                self.reloadStats(firstTime: false)
            }
            controller.push(childController)
        }
        
        private func requestClear(categories: Set<Category>, peers: Set<PeerId>, messages: Set<EngineMessage.Id>) {
            guard let component = self.component else {
                return
            }
            let context = component.context
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: presentationData)
            //TODO:localizable
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: "Clear Selected", color: .destructive, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    self?.commitClear(categories: categories, peers: peers, messages: messages)
                })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            self.controller?()?.present(actionSheet, in: .window(.root))
        }
        
        private func commitClear(categories: Set<Category>, peers: Set<PeerId>, messages: Set<EngineMessage.Id>) {
            guard let component = self.component else {
                return
            }
            
            if !categories.isEmpty {
                let peerId: EnginePeer.Id? = component.peer?.id
                
                var mappedCategories: [StorageUsageStats.CategoryKey] = []
                for category in categories {
                    switch category {
                    case .photos:
                        mappedCategories.append(.photos)
                    case .videos:
                        mappedCategories.append(.videos)
                    case .files:
                        mappedCategories.append(.files)
                    case .music:
                        mappedCategories.append(.music)
                    case .other:
                        break
                    case .stickers:
                        mappedCategories.append(.stickers)
                    case .avatars:
                        mappedCategories.append(.avatars)
                    case .misc:
                        mappedCategories.append(.misc)
                    }
                }
                let _ = (component.context.engine.resources.clearStorage(peerId: peerId, categories: mappedCategories)
                |> deliverOnMainQueue).start(completed: { [weak self] in
                    guard let self, let component = self.component, let currentStats = self.currentStats else {
                        return
                    }
                    var totalSize: Int64 = 0
                    
                    let contextStats: StorageUsageStats
                    if let peer = component.peer {
                        contextStats = currentStats.peers[peer.id]?.stats ?? StorageUsageStats(categories: [:])
                    } else {
                        contextStats = currentStats.totalStats
                    }
                    
                    for category in categories {
                        let mappedCategory: StorageUsageStats.CategoryKey
                        switch category {
                        case .photos:
                            mappedCategory = .photos
                        case .videos:
                            mappedCategory = .videos
                        case .files:
                            mappedCategory = .files
                        case .music:
                            mappedCategory = .music
                        case .other:
                            continue
                        case .stickers:
                            mappedCategory = .stickers
                        case .avatars:
                            mappedCategory = .avatars
                        case .misc:
                            mappedCategory = .misc
                        }
                        
                        if let value = contextStats.categories[mappedCategory] {
                            totalSize += value.size
                        }
                    }
                    
                    for category in categories {
                        self.selectedCategories.remove(category)
                    }
                    self.selectionState = nil
                    
                    self.reloadStats(firstTime: false)
                    
                    self.state?.updated(transition: Transition(animation: .curve(duration: 0.45, curve: .spring)).withUserData(AnimationHint(value: .clearedItems)))
                })
            } else if !peers.isEmpty {
                let _ = (component.context.engine.resources.clearStorage(peerIds: peers)
                |> deliverOnMainQueue).start(completed: { [weak self] in
                    guard let self else {
                        return
                    }
                    
                    self.selectionState = nil
                    self.reloadStats(firstTime: false)
                })
            } else if !messages.isEmpty {
                var messageItems: [Message] = []
                for id in messages {
                    if let message = self.currentMessages[id] {
                        messageItems.append(message)
                    }
                }
                
                let _ = (component.context.engine.resources.clearStorage(messages: messageItems)
                |> deliverOnMainQueue).start(completed: { [weak self] in
                    guard let self else {
                        return
                    }
                    
                    self.selectionState = nil
                    self.reloadStats(firstTime: false)
                })
            }
        }
        
        private func openKeepMediaCategory(mappedCategory: CacheStorageSettings.PeerStorageCategory, sourceView: StoragePeerTypeItemComponent.View) {
            guard let component = self.component else {
                return
            }
            let context = component.context
            let makeStorageUsageExceptionsScreen = component.makeStorageUsageExceptionsScreen
            
            let pushControllerImpl: ((ViewController) -> Void)? = { [weak self] c in
                guard let self else {
                    return
                }
                self.controller?()?.push(c)
            }
            let presentInGlobalOverlay: ((ViewController) -> Void)? = { [weak self] c in
                guard let self else {
                    return
                }
                self.controller?()?.presentInGlobalOverlay(c, with: nil)
            }
            
            let viewKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.accountSpecificCacheStorageSettings]))
            let accountSpecificSettings: Signal<AccountSpecificCacheStorageSettings, NoError> = context.account.postbox.combinedView(keys: [viewKey])
            |> map { views -> AccountSpecificCacheStorageSettings in
                let cacheSettings: AccountSpecificCacheStorageSettings
                if let view = views.views[viewKey] as? PreferencesView, let value = view.values[PreferencesKeys.accountSpecificCacheStorageSettings]?.get(AccountSpecificCacheStorageSettings.self) {
                    cacheSettings = value
                } else {
                    cacheSettings = AccountSpecificCacheStorageSettings.defaultSettings
                }

                return cacheSettings
            }
            |> distinctUntilChanged
            
            let peerExceptions: Signal<[(peer: FoundPeer, value: Int32)], NoError> = accountSpecificSettings
            |> mapToSignal { accountSpecificSettings -> Signal<[(peer: FoundPeer, value: Int32)], NoError> in
                return context.account.postbox.transaction { transaction -> [(peer: FoundPeer, value: Int32)] in
                    var result: [(peer: FoundPeer, value: Int32)] = []
                    
                    for item in accountSpecificSettings.peerStorageTimeoutExceptions {
                        let peerId = item.key
                        let value = item.value
                        
                        guard let peer = transaction.getPeer(peerId) else {
                            continue
                        }
                        let peerCategory: CacheStorageSettings.PeerStorageCategory
                        var subscriberCount: Int32?
                        if peer is TelegramUser {
                            peerCategory = .privateChats
                        } else if peer is TelegramGroup {
                            peerCategory = .groups
                            
                            if let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedGroupData {
                                subscriberCount = (cachedData.participants?.participants.count).flatMap(Int32.init)
                            }
                        } else if let channel = peer as? TelegramChannel {
                            if case .group = channel.info {
                                peerCategory = .groups
                            } else {
                                peerCategory = .channels
                            }
                            if peerCategory == mappedCategory {
                                if let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData {
                                    subscriberCount = cachedData.participantsSummary.memberCount
                                }
                            }
                        } else {
                            continue
                        }
                            
                        if peerCategory != mappedCategory {
                            continue
                        }
                        
                        result.append((peer: FoundPeer(peer: peer, subscribers: subscriberCount), value: value))
                    }
                    
                    return result.sorted(by: { lhs, rhs in
                        if lhs.value != rhs.value {
                            return lhs.value < rhs.value
                        }
                        return lhs.peer.peer.debugDisplayTitle < rhs.peer.peer.debugDisplayTitle
                    })
                }
            }
            
            let cacheSettings = context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.cacheStorageSettings])
            |> map { sharedData -> CacheStorageSettings in
                let cacheSettings: CacheStorageSettings
                if let value = sharedData.entries[SharedDataKeys.cacheStorageSettings]?.get(CacheStorageSettings.self) {
                    cacheSettings = value
                } else {
                    cacheSettings = CacheStorageSettings.defaultSettings
                }
                
                return cacheSettings
            }
            
            let _ = (combineLatest(
                cacheSettings |> take(1),
                peerExceptions |> take(1)
            )
            |> deliverOnMainQueue).start(next: { cacheSettings, peerExceptions in
                let currentValue: Int32 = cacheSettings.categoryStorageTimeout[mappedCategory] ?? Int32.max
                
                let applyValue: (Int32) -> Void = { value in
                    let _ = updateCacheStorageSettingsInteractively(accountManager: context.sharedContext.accountManager, { cacheSettings in
                        var cacheSettings = cacheSettings
                        cacheSettings.categoryStorageTimeout[mappedCategory] = value
                        return cacheSettings
                    }).start()
                }
                
                var subItems: [ContextMenuItem] = []
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                
                var presetValues: [Int32] = [
                    Int32.max,
                    31 * 24 * 60 * 60,
                    7 * 24 * 60 * 60,
                    1 * 24 * 60 * 60
                ]
                if currentValue != 0 && !presetValues.contains(currentValue) {
                    presetValues.append(currentValue)
                    presetValues.sort(by: >)
                }
                
                for value in presetValues {
                    let optionText: String
                    if value == Int32.max {
                        optionText = presentationData.strings.ClearCache_Forever
                    } else {
                        optionText = timeIntervalString(strings: presentationData.strings, value: value)
                    }
                    subItems.append(.action(ContextMenuActionItem(text: optionText, icon: { theme in
                        if currentValue == value {
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                        } else {
                            return nil
                        }
                    }, action: { _, f in
                        applyValue(value)
                        f(.default)
                    })))
                }
                
                subItems.append(.separator)
                
                if peerExceptions.isEmpty {
                    let exceptionsText = presentationData.strings.GroupInfo_Permissions_AddException
                    subItems.append(.action(ContextMenuActionItem(text: exceptionsText, icon: { theme in
                        if case .privateChats = mappedCategory {
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AddUser"), color: theme.contextMenu.primaryColor)
                        } else {
                            return generateTintedImage(image: UIImage(bundleImageName: "Location/CreateGroupIcon"), color: theme.contextMenu.primaryColor)
                        }
                    }, action: { _, f in
                        f(.default)
                        
                        if let exceptionsController = makeStorageUsageExceptionsScreen(mappedCategory) {
                            pushControllerImpl?(exceptionsController)
                        }
                    })))
                } else {
                    subItems.append(.custom(MultiplePeerAvatarsContextItem(context: context, peers: peerExceptions.prefix(3).map { EnginePeer($0.peer.peer) }, action: { c, _ in
                        c.dismiss(completion: {
                            
                        })
                        if let exceptionsController = makeStorageUsageExceptionsScreen(mappedCategory) {
                            pushControllerImpl?(exceptionsController)
                        }
                    }), false))
                }
                
                if let sourceLabelView = sourceView.labelView {
                    let items: Signal<ContextController.Items, NoError> = .single(ContextController.Items(content: .list(subItems)))
                    let source: ContextContentSource = .reference(StorageUsageContextReferenceContentSource(sourceView: sourceLabelView))
                    
                    let contextController = ContextController(
                        account: context.account,
                        presentationData: presentationData,
                        source: source,
                        items: items,
                        gesture: nil
                    )
                    sourceView.setHasAssociatedMenu(true)
                    contextController.dismissed = { [weak sourceView] in
                        sourceView?.setHasAssociatedMenu(false)
                    }
                    presentInGlobalOverlay?(contextController)
                }
            })
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class StorageUsageScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    fileprivate var reloadParent: (() -> Void)?
    
    public init(context: AccountContext, makeStorageUsageExceptionsScreen: @escaping (CacheStorageSettings.PeerStorageCategory) -> ViewController?, peer: EnginePeer? = nil) {
        self.context = context
        
        super.init(context: context, component: StorageUsageScreenComponent(context: context, makeStorageUsageExceptionsScreen: makeStorageUsageExceptionsScreen, peer: peer), navigationBarAppearance: .transparent)
        
        if peer != nil {
            self.navigationPresentation = .modal
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
    }
}

private final class StorageUsageContextReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView
    
    init(sourceView: UIView) {
        self.sourceView = sourceView
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds, insets: UIEdgeInsets(top: -4.0, left: 0.0, bottom: -4.0, right: 0.0))
    }
}

final class MultiplePeerAvatarsContextItem: ContextMenuCustomItem {
    fileprivate let context: AccountContext
    fileprivate let peers: [EnginePeer]
    fileprivate let action: (ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void) -> Void

    init(context: AccountContext, peers: [EnginePeer], action: @escaping (ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void) -> Void) {
        self.context = context
        self.peers = peers
        self.action = action
    }

    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return MultiplePeerAvatarsContextItemNode(presentationData: presentationData, item: self, getController: getController, actionSelected: actionSelected)
    }
}

private final class MultiplePeerAvatarsContextItemNode: ASDisplayNode, ContextMenuCustomNode, ContextActionNodeProtocol {
    private let item: MultiplePeerAvatarsContextItem
    private var presentationData: PresentationData
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void

    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let textNode: ImmediateTextNode

    private let avatarsNode: AnimatedAvatarSetNode
    private let avatarsContext: AnimatedAvatarSetContext

    private let buttonNode: HighlightTrackingButtonNode

    private var pointerInteraction: PointerInteraction?

    init(presentationData: PresentationData, item: MultiplePeerAvatarsContextItem, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.item = item
        self.presentationData = presentationData
        self.getController = getController
        self.actionSelected = actionSelected

        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)

        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isAccessibilityElement = false
        self.backgroundNode.backgroundColor = presentationData.theme.contextMenu.itemBackgroundColor
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isAccessibilityElement = false
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        self.highlightedBackgroundNode.alpha = 0.0

        self.textNode = ImmediateTextNode()
        self.textNode.isAccessibilityElement = false
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = NSAttributedString(string: " ", font: textFont, textColor: presentationData.theme.contextMenu.primaryColor)
        self.textNode.maximumNumberOfLines = 1

        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.isAccessibilityElement = true
        self.buttonNode.accessibilityLabel = presentationData.strings.VoiceChat_StopRecording

        self.avatarsNode = AnimatedAvatarSetNode()
        self.avatarsContext = AnimatedAvatarSetContext()

        super.init()

        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.avatarsNode)
        self.addSubnode(self.buttonNode)

        self.buttonNode.highligthedChanged = { [weak self] highligted in
            guard let strongSelf = self else {
                return
            }
            if highligted {
                strongSelf.highlightedBackgroundNode.alpha = 1.0
            } else {
                strongSelf.highlightedBackgroundNode.alpha = 0.0
                strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
            }
        }
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.isUserInteractionEnabled = true
    }

    deinit {
    }

    override func didLoad() {
        super.didLoad()

        self.pointerInteraction = PointerInteraction(node: self.buttonNode, style: .hover, willEnter: { [weak self] in
            if let strongSelf = self {
                strongSelf.highlightedBackgroundNode.alpha = 0.75
            }
        }, willExit: { [weak self] in
            if let strongSelf = self {
                strongSelf.highlightedBackgroundNode.alpha = 0.0
            }
        })
    }

    private var validLayout: (calculatedWidth: CGFloat, size: CGSize)?

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let sideInset: CGFloat = 14.0
        let verticalInset: CGFloat = 12.0

        let rightTextInset: CGFloat = sideInset + 36.0

        let calculatedWidth = min(constrainedWidth, 250.0)

        let textFont = Font.regular(self.presentationData.listsFontSize.baseDisplaySize)
        let text: String = self.presentationData.strings.CacheEvictionMenu_CategoryExceptions(Int32(self.item.peers.count))
        self.textNode.attributedText = NSAttributedString(string: text, font: textFont, textColor: self.presentationData.theme.contextMenu.primaryColor)

        let textSize = self.textNode.updateLayout(CGSize(width: calculatedWidth - sideInset - rightTextInset, height: .greatestFiniteMagnitude))

        let combinedTextHeight = textSize.height
        return (CGSize(width: calculatedWidth, height: verticalInset * 2.0 + combinedTextHeight), { size, transition in
            self.validLayout = (calculatedWidth: calculatedWidth, size: size)
            let verticalOrigin = floor((size.height - combinedTextHeight) / 2.0)
            let textFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin), size: textSize)
            transition.updateFrameAdditive(node: self.textNode, frame: textFrame)

            let avatarsContent: AnimatedAvatarSetContext.Content

            let avatarsPeers: [EnginePeer] = self.item.peers
            
            avatarsContent = self.avatarsContext.update(peers: avatarsPeers, animated: false)

            let avatarsSize = self.avatarsNode.update(context: self.item.context, content: avatarsContent, itemSize: CGSize(width: 24.0, height: 24.0), customSpacing: 10.0, animated: false, synchronousLoad: true)
            self.avatarsNode.frame = CGRect(origin: CGPoint(x: size.width - sideInset - 12.0 - avatarsSize.width, y: floor((size.height - avatarsSize.height) / 2.0)), size: avatarsSize)

            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
        })
    }

    func updateTheme(presentationData: PresentationData) {
        self.presentationData = presentationData

        self.backgroundNode.backgroundColor = presentationData.theme.contextMenu.itemBackgroundColor
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor

        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)

        self.textNode.attributedText = NSAttributedString(string: self.textNode.attributedText?.string ?? "", font: textFont, textColor: presentationData.theme.contextMenu.primaryColor)
    }

    @objc private func buttonPressed() {
        self.performAction()
    }

    private var actionTemporarilyDisabled: Bool = false
    
    func canBeHighlighted() -> Bool {
        return self.isActionEnabled
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
        self.setIsHighlighted(isHighlighted)
    }

    func performAction() {
        if self.actionTemporarilyDisabled {
            return
        }
        self.actionTemporarilyDisabled = true
        Queue.mainQueue().async { [weak self] in
            self?.actionTemporarilyDisabled = false
        }

        guard let controller = self.getController() else {
            return
        }
        self.item.action(controller, { [weak self] result in
            self?.actionSelected(result)
        })
    }

    var isActionEnabled: Bool {
        return true
    }

    func setIsHighlighted(_ value: Bool) {
        if value {
            self.highlightedBackgroundNode.alpha = 1.0
        } else {
            self.highlightedBackgroundNode.alpha = 0.0
        }
    }
    
    func actionNode(at point: CGPoint) -> ContextActionNodeProtocol {
        return self
    }
}
