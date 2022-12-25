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
import RadialStatusNode
import UndoUI
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import TelegramStringFormatting

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
        
        convenience init() {
            self.init(
                selectedPeers: Set(),
                selectedMessages: Set()
            )
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
                return strings.StorageManagement_SectionPhotos
            case .videos:
                return strings.StorageManagement_SectionVideos
            case .files:
                return strings.StorageManagement_SectionFiles
            case .music:
                return strings.StorageManagement_SectionMusic
            case .other:
                return strings.StorageManagement_SectionOther
            case .stickers:
                return strings.StorageManagement_SectionStickers
            case .avatars:
                return strings.StorageManagement_SectionAvatars
            case .misc:
                return strings.StorageManagement_SectionMiscellaneous
            }
        }
    }
    
    class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollViewImpl
        
        private var currentStats: AllStorageUsageStats?
        private var existingCategories: Set<Category> = Set()
        
        private var currentMessages: [MessageId: Message] = [:]
        private var cacheSettings: CacheStorageSettings?
        private var cacheSettingsExceptionCount: [CacheStorageSettings.PeerStorageCategory: Int32]?
        
        private var peerItems: StoragePeerListPanelComponent.Items?
        private var imageItems: StorageFileListPanelComponent.Items?
        private var fileItems: StorageFileListPanelComponent.Items?
        private var musicItems: StorageFileListPanelComponent.Items?
        
        private var selectionState: SelectionState?
        
        private var clearingDisplayTimestamp: Double?
        private var isClearing: Bool = false {
            didSet {
                if self.isClearing != oldValue {
                    if self.isClearing {
                        if self.keepScreenActiveDisposable == nil {
                            self.keepScreenActiveDisposable = self.component?.context.sharedContext.applicationBindings.pushIdleTimerExtension()
                        }
                    } else {
                        if let keepScreenActiveDisposable = self.keepScreenActiveDisposable {
                            self.keepScreenActiveDisposable = nil
                            keepScreenActiveDisposable.dispose()
                        }
                    }
                }
            }
        }
        
        private var selectedCategories: Set<Category> = Set()
        private var isOtherCategoryExpanded: Bool = false
        
        private let navigationBackgroundView: BlurredBackgroundView
        private let navigationSeparatorLayer: SimpleLayer
        private let navigationSeparatorLayerContainer: SimpleLayer
        private let navigationEditButton = ComponentView<Empty>()
        private let navigationDoneButton = ComponentView<Empty>()
        
        private let headerView = ComponentView<Empty>()
        private let headerOffsetContainer: UIView
        private let headerDescriptionView = ComponentView<Empty>()
        
        private let headerProgressBackgroundLayer: SimpleLayer
        private let headerProgressForegroundLayer: SimpleLayer
        
        private var chartAvatarNode: AvatarNode?
        
        private var doneStatusCircle: SimpleShapeLayer?
        private var doneStatusNode: RadialStatusNode?
        
        private let pieChartView = ComponentView<Empty>()
        private let chartTotalLabel = ComponentView<Empty>()
        private let categoriesView = ComponentView<Empty>()
        private let categoriesDescriptionView = ComponentView<Empty>()
        
        private let keepDurationTitleView = ComponentView<Empty>()
        private let keepDurationDescriptionView = ComponentView<Empty>()
        private var keepDurationSectionContainerView: UIView
        private var keepDurationItems: [AnyHashable: ComponentView<Empty>] = [:]
        
        private let keepSizeTitleView = ComponentView<Empty>()
        private let keepSizeView = ComponentView<Empty>()
        private let keepSizeDescriptionView = ComponentView<Empty>()
        
        private let panelContainer = ComponentView<StorageUsagePanelContainerEnvironment>()
        
        private var selectionPanel: ComponentView<Empty>?
        
        private var clearingNode: StorageUsageClearProgressOverlayNode?
        
        private var loadingView: UIActivityIndicatorView?
        
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
        private var keepScreenActiveDisposable: Disposable?
        
        override init(frame: CGRect) {
            self.headerOffsetContainer = UIView()
            self.headerOffsetContainer.isUserInteractionEnabled = false
            
            self.navigationBackgroundView = BlurredBackgroundView(color: nil, enableBlur: true)
            self.navigationBackgroundView.alpha = 0.0
            
            self.navigationSeparatorLayer = SimpleLayer()
            self.navigationSeparatorLayer.opacity = 0.0
            self.navigationSeparatorLayerContainer = SimpleLayer()
            self.navigationSeparatorLayerContainer.opacity = 0.0
            
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
            
            self.navigationSeparatorLayerContainer.addSublayer(self.navigationSeparatorLayer)
            self.layer.addSublayer(self.navigationSeparatorLayerContainer)
            
            self.addSubview(self.headerOffsetContainer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.statsDisposable?.dispose()
            self.messagesDisposable?.dispose()
            self.keepScreenActiveDisposable?.dispose()
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
            guard let _ = self.navigationMetrics else {
                return
            }
            
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
                animatedTransition.setAlpha(layer: self.navigationSeparatorLayerContainer, alpha: navigationBackgroundAlpha)
                
                if let navigationEditButtonView = self.navigationEditButton.view {
                    animatedTransition.setAlpha(view: navigationEditButtonView, alpha: (self.selectionState == nil ? 1.0 : 0.0) * navigationBackgroundAlpha)
                }
                if let navigationDoneButtonView = self.navigationDoneButton.view {
                    animatedTransition.setAlpha(view: navigationDoneButtonView, alpha: (self.selectionState == nil ? 0.0 : 1.0) * navigationBackgroundAlpha)
                }
                
                let expansionDistance: CGFloat = 32.0
                var expansionDistanceFactor: CGFloat = abs(scrollBounds.maxY - self.scrollView.contentSize.height) / expansionDistance
                expansionDistanceFactor = max(0.0, min(1.0, expansionDistanceFactor))
                
                transition.setAlpha(layer: self.navigationSeparatorLayer, alpha: expansionDistanceFactor)
                if let panelContainerView = self.panelContainer.view as? StorageUsagePanelContainerComponent.View {
                    panelContainerView.updateNavigationMergeFactor(value: 1.0 - expansionDistanceFactor, transition: transition)
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
            
            if self.currentStats == nil {
                let loadingView: UIActivityIndicatorView
                if let current = self.loadingView {
                    loadingView = current
                } else {
                    let style: UIActivityIndicatorView.Style
                    if environment.theme.overallDarkAppearance {
                        style = .whiteLarge
                    } else {
                        if #available(iOS 13.0, *) {
                            style = .large
                        } else {
                            style = .gray
                        }
                    }
                    loadingView = UIActivityIndicatorView(style: style)
                    self.loadingView = loadingView
                    loadingView.sizeToFit()
                    self.insertSubview(loadingView, belowSubview: self.scrollView)
                }
                let loadingViewSize = loadingView.bounds.size
                transition.setFrame(view: loadingView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - loadingViewSize.width) / 2.0), y: floor((availableSize.height - loadingViewSize.height) / 2.0)), size: loadingViewSize))
                if !loadingView.isAnimating {
                    loadingView.startAnimating()
                }
            } else {
                if let loadingView = self.loadingView {
                    self.loadingView = nil
                    loadingView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak loadingView] _ in
                        loadingView?.removeFromSuperview()
                    })
                }
            }
            
            if self.statsDisposable == nil {
                let context = component.context
                let viewKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.accountSpecificCacheStorageSettings]))
                let cacheSettingsExceptionCount: Signal<[CacheStorageSettings.PeerStorageCategory: Int32], NoError> = component.context.account.postbox.combinedView(keys: [viewKey])
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
                |> mapToSignal { accountSpecificSettings -> Signal<[CacheStorageSettings.PeerStorageCategory: Int32], NoError> in
                    return context.engine.data.get(
                        EngineDataMap(accountSpecificSettings.peerStorageTimeoutExceptions.map(\.key).map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
                    )
                    |> map { peers -> [CacheStorageSettings.PeerStorageCategory: Int32] in
                        var result: [CacheStorageSettings.PeerStorageCategory: Int32] = [:]
                        
                        for (_, peer) in peers {
                            guard let peer else {
                                continue
                            }
                            switch peer {
                            case .user, .secretChat:
                                result[.privateChats, default: 0] += 1
                            case .legacyGroup:
                                result[.groups, default: 0] += 1
                            case let .channel(channel):
                                if case .group = channel.info {
                                    result[.groups, default: 0] += 1
                                } else {
                                    result[.channels, default: 0] += 1
                                }
                            }
                        }
                        
                        return result
                    }
                }
                
                self.cacheSettingsDisposable = (combineLatest(queue: .mainQueue(),
                    component.context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.cacheStorageSettings])
                    |> map { sharedData -> CacheStorageSettings in
                        let cacheSettings: CacheStorageSettings
                        if let value = sharedData.entries[SharedDataKeys.cacheStorageSettings]?.get(CacheStorageSettings.self) {
                            cacheSettings = value
                        } else {
                            cacheSettings = CacheStorageSettings.defaultSettings
                        }
                        
                        return cacheSettings
                    },
                    cacheSettingsExceptionCount
                )
                |> deliverOnMainQueue).start(next: { [weak self] cacheSettings, cacheSettingsExceptionCount in
                    guard let self else {
                        return
                    }
                    self.cacheSettings = cacheSettings
                    self.cacheSettingsExceptionCount = cacheSettingsExceptionCount
                    if self.currentStats != nil {
                        self.state?.updated(transition: .immediate)
                    }
                })
                
                self.reloadStats(firstTime: true, completion: {})
            }
            
            var wasLockedAtPanels = false
            if let panelContainerView = self.panelContainer.view, let navigationMetrics = self.navigationMetrics {
                if self.scrollView.bounds.minY > 0.0 && abs(self.scrollView.bounds.minY - (panelContainerView.frame.minY - navigationMetrics.navigationHeight)) <= UIScreenPixel {
                    wasLockedAtPanels = true
                }
            }
            
            let animationHint = transition.userData(AnimationHint.self)
            
            if let animationHint {
                if case .firstStatsUpdate = animationHint.value {
                    let alphaTransition: Transition = .easeInOut(duration: 0.25)
                    alphaTransition.setAlpha(view: self.scrollView, alpha: self.currentStats != nil ? 1.0 : 0.0)
                    alphaTransition.setAlpha(view: self.headerOffsetContainer, alpha: self.currentStats != nil ? 1.0 : 0.0)
                } else if case .clearedItems = animationHint.value {
                    if let snapshotView = self.snapshotView(afterScreenUpdates: false) {
                        snapshotView.frame = self.bounds
                        self.addSubview(snapshotView)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                }
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
            
            let navigationSeparatorFrame = CGRect(origin: CGPoint(x: 0.0, y: navigationFrame.maxY), size: CGSize(width: availableSize.width, height: UIScreenPixel))
            
            transition.setFrame(layer: self.navigationSeparatorLayerContainer, frame: navigationSeparatorFrame)
            transition.setFrame(layer: self.navigationSeparatorLayer, frame: CGRect(origin: CGPoint(), size: navigationSeparatorFrame.size))
            
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
                transition.setFrame(view: navigationEditButtonView, frame: CGRect(origin: CGPoint(x: availableSize.width - 12.0 - environment.safeInsets.right - navigationEditButtonSize.width, y: environment.statusBarHeight), size: navigationEditButtonSize))
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
                transition.setFrame(view: navigationDoneButtonView, frame: CGRect(origin: CGPoint(x: availableSize.width - 12.0 - environment.safeInsets.right - navigationDoneButtonSize.width, y: environment.statusBarHeight), size: navigationDoneButtonSize))
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
                
                let selectionPanelSize = selectionPanel.update(
                    transition: selectionPanelTransition,
                    component: AnyComponent(StorageUsageScreenSelectionPanelComponent(
                        theme: environment.theme,
                        title: environment.strings.StorageManagement_ClearSelected,
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
            
            if let _ = self.currentStats {
                if let animationHint {
                    switch animationHint.value {
                    case .firstStatsUpdate, .clearedItems:
                        self.selectedCategories = self.existingCategories
                    }
                }
                
                self.selectedCategories.formIntersection(self.existingCategories)
            } else {
                self.selectedCategories.removeAll()
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
                        chartCategoryColor = Category.misc.color
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
                
                let listColor: UIColor
                if self.isOtherCategoryExpanded {
                    listColor = Category.other.color
                } else {
                    listColor = Category.misc.color
                }
                
                listCategories.append(StorageCategoriesComponent.CategoryData(
                    key: Category.other, color: listColor, title: Category.other.title(strings: environment.strings), size: totalOtherSize, sizeFraction: categoryFraction, isSelected: isSelected, subcategories: otherListCategories))
            }
            
            if !self.isOtherCategoryExpanded {
                var otherSum: CGFloat = 0.0
                var otherRealSum: CGFloat = 0.0
                for i in 0 ..< chartItems.count {
                    if otherCategories.contains(chartItems[i].id) {
                        var itemValue = chartItems[i].value
                        if itemValue > 0.00001 {
                            itemValue = max(itemValue, 0.01)
                        }
                        otherSum += itemValue
                        otherRealSum += chartItems[i].displayValue
                        if case .misc = chartItems[i].id {
                        } else {
                            chartItems[i].value = 0.0
                        }
                    }
                }
                if let index = chartItems.firstIndex(where: { $0.id == .misc }) {
                    chartItems[index].value = otherSum
                    chartItems[index].displayValue = otherRealSum
                }
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
                transition.setAlpha(view: pieChartComponentView, alpha: listCategories.isEmpty ? 0.0 : 1.0)
            }
            if let _ = self.currentStats, listCategories.isEmpty {
                let checkColor = UIColor(rgb: 0x34C759)
                
                let doneStatusNode: RadialStatusNode
                var animateIn = false
                if let current = self.doneStatusNode {
                    doneStatusNode = current
                } else {
                    doneStatusNode = RadialStatusNode(backgroundNodeColor: .clear)
                    self.doneStatusNode = doneStatusNode
                    self.scrollView.addSubnode(doneStatusNode)
                    animateIn = true
                }
                let doneSize = CGSize(width: 100.0, height: 100.0)
                doneStatusNode.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - doneSize.width) / 2.0), y: contentHeight), size: doneSize)
                
                let doneStatusCircle: SimpleShapeLayer
                if let current = self.doneStatusCircle {
                    doneStatusCircle = current
                } else {
                    doneStatusCircle = SimpleShapeLayer()
                    self.doneStatusCircle = doneStatusCircle
                    self.scrollView.layer.addSublayer(doneStatusCircle)
                    doneStatusCircle.opacity = 0.0
                }
                
                if animateIn {
                    Queue.mainQueue().after(0.18, {
                        doneStatusNode.transitionToState(.check(checkColor), animated: true)
                        doneStatusCircle.opacity = 1.0
                        doneStatusCircle.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
                    })
                }
                
                doneStatusCircle.lineWidth = 6.0
                doneStatusCircle.strokeColor = checkColor.cgColor
                doneStatusCircle.fillColor = nil
                doneStatusCircle.path = UIBezierPath(ovalIn: CGRect(origin: CGPoint(x: doneStatusCircle.lineWidth * 0.5, y: doneStatusCircle.lineWidth * 0.5), size: CGSize(width: doneSize.width - doneStatusCircle.lineWidth * 0.5, height: doneSize.height - doneStatusCircle.lineWidth * 0.5))).cgPath
                
                doneStatusCircle.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - doneSize.width) / 2.0), y: contentHeight), size: doneSize).insetBy(dx: -doneStatusCircle.lineWidth * 0.5, dy: -doneStatusCircle.lineWidth * 0.5)
                
                contentHeight += doneSize.height
            } else {
                contentHeight += pieChartSize.height
                
                if let doneStatusNode = self.doneStatusNode {
                    self.doneStatusNode = nil
                    doneStatusNode.removeFromSupernode()
                }
                if let doneStatusCircle = self.doneStatusCircle {
                    self.doneStatusCircle = nil
                    doneStatusCircle.removeFromSuperlayer()
                }
            }
            
            contentHeight += 23.0
            
            let headerText: String
            if listCategories.isEmpty {
                headerText = environment.strings.StorageManagement_TitleCleared
            } else if let peer = component.peer {
                headerText = peer.displayTitle(strings: environment.strings, displayOrder: .firstLast)
            } else {
                headerText = environment.strings.StorageManagement_Title
            }
            let headerViewSize = self.headerView.update(
                transition: transition,
                component: AnyComponent(Text(text: headerText, font: Font.semibold(20.0), color: environment.theme.list.itemPrimaryTextColor)),
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
            
            contentHeight += 6.0
            
            let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.freeTextColor)
            let bold = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.freeTextColor)
            
            var usageFraction: Double = 0.0
            let totalUsageText: String
            if listCategories.isEmpty {
                totalUsageText = environment.strings.StorageManagement_DescriptionCleared
            } else if let currentStats = self.currentStats {
                let contextStats: StorageUsageStats
                if let peer = component.peer {
                    contextStats = currentStats.peers[peer.id]?.stats ?? StorageUsageStats(categories: [:])
                } else {
                    contextStats = currentStats.totalStats
                }
                
                var totalStatsSize: Int64 = 0
                for (_, value) in contextStats.categories {
                    totalStatsSize += value.size
                }
                
                if let _ = component.peer {
                    var allStatsSize: Int64 = 0
                    for (_, value) in currentStats.totalStats.categories {
                        allStatsSize += value.size
                    }
                    
                    let fraction: Double
                    if allStatsSize != 0 {
                        fraction = Double(totalStatsSize) / Double(allStatsSize)
                    } else {
                        fraction = 0.0
                    }
                    usageFraction = fraction
                    let fractionValue: Double = floor(fraction * 100.0 * 10.0) / 10.0
                    let fractionString: String
                    if fractionValue < 0.1 {
                        fractionString = "<0.1"
                    } else if abs(Double(Int(fractionValue)) - fractionValue) < 0.001 {
                        fractionString = "\(Int(fractionValue))"
                    } else {
                        fractionString = "\(fractionValue)"
                    }
                        
                    totalUsageText = environment.strings.StorageManagement_DescriptionChatUsage(fractionString).string
                } else {
                    let fraction: Double
                    if currentStats.deviceFreeSpace != 0 && totalStatsSize != 0 {
                        fraction = Double(totalStatsSize) / Double(currentStats.deviceFreeSpace + totalStatsSize)
                    } else {
                        fraction = 0.0
                    }
                    usageFraction = fraction
                    let fractionValue: Double = floor(fraction * 100.0 * 10.0) / 10.0
                    let fractionString: String
                    if fractionValue < 0.1 {
                        fractionString = "<0.1"
                    } else if abs(Double(Int(fractionValue)) - fractionValue) < 0.001 {
                        fractionString = "\(Int(fractionValue))"
                    } else {
                        fractionString = "\(fractionValue)"
                    }
                        
                    totalUsageText = environment.strings.StorageManagement_DescriptionAppUsage(fractionString).string
                }
            } else {
                totalUsageText = " "
            }
            let headerDescriptionSize = self.headerDescriptionView.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(text: .markdown(text: totalUsageText, attributes: MarkdownAttributes(
                    body: body,
                    bold: bold,
                    link: body,
                    linkAttribute: { _ in nil }
                )), horizontalAlignment: .center, maximumNumberOfLines: 0)),
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
            
            let headerProgress: CGFloat = usageFraction
            transition.setFrame(layer: self.headerProgressForegroundLayer, frame: CGRect(origin: headerProgressFrame.origin, size: CGSize(width: max(headerProgressFrame.height, floorToScreenPixels(headerProgress * headerProgressFrame.width)), height: headerProgressFrame.height)))
            transition.setCornerRadius(layer: self.headerProgressForegroundLayer, cornerRadius: headerProgressFrame.height * 0.5)
            self.headerProgressForegroundLayer.backgroundColor = environment.theme.list.itemAccentColor.cgColor
            contentHeight += 4.0
            
            transition.setAlpha(layer: self.headerProgressBackgroundLayer, alpha: listCategories.isEmpty ? 0.0 : 1.0)
            transition.setAlpha(layer: self.headerProgressForegroundLayer, alpha: listCategories.isEmpty ? 0.0 : 1.0)
            
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
                transition.setAlpha(view: chartAvatarNode.view, alpha: listCategories.isEmpty ? 0.0 : 1.0)
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
                    transition.setAlpha(view: chartTotalLabelView, alpha: listCategories.isEmpty ? 0.0 : 1.0)
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
                                var otherCategories: [Category] = [.stickers, .avatars, .misc]
                                otherCategories = otherCategories.filter(self.existingCategories.contains)
                                if !otherCategories.isEmpty {
                                    if otherCategories.allSatisfy(self.selectedCategories.contains) {
                                        for item in otherCategories {
                                            self.selectedCategories.remove(item)
                                        }
                                    } else {
                                        for item in otherCategories {
                                            let _ = self.selectedCategories.insert(item)
                                        }
                                    }
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
                
                
                let categoriesDescriptionSize = self.categoriesDescriptionView.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(text: .markdown(text: environment.strings.StorageManagement_SectionsDescription, attributes: MarkdownAttributes(
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
                let keepDurationTitleSize = self.keepDurationTitleView.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .markdown(
                            text: environment.strings.StorageManagement_AutoremoveHeader, attributes: MarkdownAttributes(
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
                    
                    let iconName: String
                    let title: String
                    switch i {
                    case 0:
                        iconName = "Settings/Menu/EditProfile"
                        title = environment.strings.Notifications_PrivateChats
                        mappedCategory = .privateChats
                    case 1:
                        iconName = "Settings/Menu/GroupChats"
                        title = environment.strings.Notifications_GroupChats
                        mappedCategory = .groups
                    default:
                        iconName = "Settings/Menu/Channels"
                        title = environment.strings.Notifications_Channels
                        mappedCategory = .channels
                    }
                    
                    let value = self.cacheSettings?.categoryStorageTimeout[mappedCategory] ?? Int32.max
                    let optionText: String
                    if value == Int32.max {
                        optionText = environment.strings.ClearCache_Never
                    } else {
                        optionText = timeIntervalString(strings: environment.strings, value: value)
                    }
                    
                    var subtitle: String?
                    if let cacheSettingsExceptionCount = self.cacheSettingsExceptionCount, let categoryCount = cacheSettingsExceptionCount[mappedCategory] {
                        subtitle = environment.strings.CacheEvictionMenu_CategoryExceptions(Int32(categoryCount))
                    }
                    
                    let itemSize = item.update(
                        transition: transition,
                        component: AnyComponent(StoragePeerTypeItemComponent(
                            theme: environment.theme,
                            iconName: iconName,
                            title: title,
                            subtitle: subtitle,
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
                
                let keepDurationDescriptionSize = self.keepDurationDescriptionView.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .markdown(
                            text: environment.strings.StorageManagement_AutoremoveDescription, attributes: MarkdownAttributes(
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
                
                let keepSizeTitleSize = self.keepSizeTitleView.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .markdown(
                            text: environment.strings.Cache_MaximumCacheSize.uppercased(), attributes: MarkdownAttributes(
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
                let keepSizeTitleFrame = CGRect(origin: CGPoint(x: sideInset + 15.0, y: contentHeight), size: keepSizeTitleSize)
                if let keepSizeTitleComponentView = self.keepSizeTitleView.view {
                    if keepSizeTitleComponentView.superview == nil {
                        self.scrollView.addSubview(keepSizeTitleComponentView)
                    }
                    transition.setFrame(view: keepSizeTitleComponentView, frame: keepSizeTitleFrame)
                }
                contentHeight += keepSizeTitleSize.height
                contentHeight += 8.0
                
                let keepSizeSize = self.keepSizeView.update(
                    transition: transition,
                    component: AnyComponent(StorageKeepSizeComponent(
                        theme: environment.theme,
                        strings: environment.strings,
                        value: cacheSettings?.defaultCacheStorageLimitGigabytes ?? 32,
                        updateValue: { [weak self] value in
                            guard let self, let component = self.component else {
                                return
                            }
                            let value = max(5, value)
                            let _ = updateCacheStorageSettingsInteractively(accountManager: component.context.sharedContext.accountManager, { current in
                                var current = current
                                current.defaultCacheStorageLimitGigabytes = value
                                return current
                            }).start()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let keepSizeFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: keepSizeSize)
                if let keepSizeComponentView = self.keepSizeView.view {
                    if keepSizeComponentView.superview == nil {
                        self.scrollView.addSubview(keepSizeComponentView)
                    }
                    transition.setFrame(view: keepSizeComponentView, frame: keepSizeFrame)
                }
                contentHeight += keepSizeSize.height
                contentHeight += 8.0
                
                let keepSizeDescriptionSize = self.keepSizeDescriptionView.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .markdown(
                            text: environment.strings.StorageManagement_AutoremoveSpaceDescription, attributes: MarkdownAttributes(
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
                let keepSizeDescriptionFrame = CGRect(origin: CGPoint(x: sideInset + 15.0, y: contentHeight), size: keepSizeDescriptionSize)
                if let keepSizeDescriptionComponentView = self.keepSizeDescriptionView.view {
                    if keepSizeDescriptionComponentView.superview == nil {
                        self.scrollView.addSubview(keepSizeDescriptionComponentView)
                    }
                    transition.setFrame(view: keepSizeDescriptionComponentView, frame: keepSizeDescriptionFrame)
                }
                contentHeight += keepSizeDescriptionSize.height
                contentHeight += 40.0
            }
            
            var panelItems: [StorageUsagePanelContainerComponent.Item] = []
            if let peerItems = self.peerItems, !peerItems.items.isEmpty, !listCategories.isEmpty {
                panelItems.append(StorageUsagePanelContainerComponent.Item(
                    id: "peers",
                    title: environment.strings.StorageManagement_TabChats,
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
            if let imageItems = self.imageItems, !imageItems.items.isEmpty, !listCategories.isEmpty {
                panelItems.append(StorageUsagePanelContainerComponent.Item(
                    id: "images",
                    title: environment.strings.StorageManagement_TabMedia,
                    panel: AnyComponent(StorageFileListPanelComponent(
                        context: component.context,
                        items: self.imageItems,
                        selectionState: self.selectionState,
                        peerAction: { [weak self] messageId in
                            guard let self else {
                                return
                            }
                            if self.selectionState == nil {
                                self.selectionState = SelectionState()
                            }
                            self.selectionState = self.selectionState?.toggleMessage(id: messageId)
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                        }
                    ))
                ))
            }
            if let fileItems = self.fileItems, !fileItems.items.isEmpty, !listCategories.isEmpty {
                panelItems.append(StorageUsagePanelContainerComponent.Item(
                    id: "files",
                    title: environment.strings.StorageManagement_TabFiles,
                    panel: AnyComponent(StorageFileListPanelComponent(
                        context: component.context,
                        items: self.fileItems,
                        selectionState: self.selectionState,
                        peerAction: { [weak self] messageId in
                            guard let self else {
                                return
                            }
                            if self.selectionState == nil {
                                self.selectionState = SelectionState()
                            }
                            self.selectionState = self.selectionState?.toggleMessage(id: messageId)
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                        }
                    ))
                ))
            }
            if let musicItems = self.musicItems, !musicItems.items.isEmpty, !listCategories.isEmpty {
                panelItems.append(StorageUsagePanelContainerComponent.Item(
                    id: "music",
                    title: environment.strings.StorageManagement_TabMusic,
                    panel: AnyComponent(StorageFileListPanelComponent(
                        context: component.context,
                        items: self.musicItems,
                        selectionState: self.selectionState,
                        peerAction: { [weak self] messageId in
                            guard let self else {
                                return
                            }
                            if self.selectionState == nil {
                                self.selectionState = SelectionState()
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
            
            if self.isClearing {
                let clearingNode: StorageUsageClearProgressOverlayNode
                var animateIn = false
                if let current = self.clearingNode {
                    clearingNode = current
                } else {
                    animateIn = true
                    clearingNode = StorageUsageClearProgressOverlayNode(presentationData: component.context.sharedContext.currentPresentationData.with { $0 })
                    self.clearingNode = clearingNode
                    self.addSubnode(clearingNode)
                    self.clearingDisplayTimestamp = CFAbsoluteTimeGetCurrent()
                }
                
                let clearingSize = CGSize(width: availableSize.width, height: availableSize.height)
                clearingNode.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - clearingSize.width) / 2.0), y: floor((availableSize.height - clearingSize.height) / 2.0)), size: clearingSize)
                clearingNode.updateLayout(size: clearingSize, transition: .immediate)
                
                if animateIn {
                    clearingNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, delay: 0.15)
                }
            } else {
                if let clearingNode = self.clearingNode {
                    self.clearingNode = nil
                    
                    var delay: Double = 0.0
                    if let clearingDisplayTimestamp = self.clearingDisplayTimestamp {
                        let timeDelta = CFAbsoluteTimeGetCurrent() - clearingDisplayTimestamp
                        if timeDelta < 0.12 {
                            delay = 0.0
                        } else if timeDelta < 0.4 {
                            delay = 0.4
                        }
                    }
                    
                    if delay == 0.0 {
                        let animationTransition = Transition(animation: .curve(duration: 0.25, curve: .easeInOut))
                        animationTransition.setAlpha(view: clearingNode.view, alpha: 0.0, completion: { [weak clearingNode] _ in
                            clearingNode?.removeFromSupernode()
                        })
                    } else {
                        clearingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, delay: delay, removeOnCompletion: false, completion: { [weak clearingNode] _ in
                            clearingNode?.removeFromSupernode()
                        })
                    }
                }
            }
            
            return availableSize
        }
        
        private func reportClearedStorage(size: Int64) {
            guard let component = self.component else {
                return
            }
            guard let controller = self.controller?() else {
                return
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            controller.present(UndoOverlayController(presentationData: presentationData, content: .succeed(text: presentationData.strings.ClearCache_Success("\(dataSizeString(size, formatting: DataSizeStringFormatting(presentationData: presentationData)))", stringForDeviceType()).string), elevatedLayout: false, action: { _ in return false }), in: .window(.root))
        }
        
        private func reloadStats(firstTime: Bool, completion: @escaping () -> Void) {
            guard let component = self.component else {
                completion()
                return
            }
            
            self.statsDisposable = (component.context.engine.resources.collectStorageUsageStats()
            |> deliverOnMainQueue).start(next: { [weak self] stats in
                guard let self, let component = self.component else {
                    completion()
                    return
                }
                
                var existingCategories = Set<Category>()
                let contextStats: StorageUsageStats
                if let peer = component.peer {
                    contextStats = stats.peers[peer.id]?.stats ?? StorageUsageStats(categories: [:])
                } else {
                    contextStats = stats.totalStats
                }
                for (category, value) in contextStats.categories {
                    if value.size != 0 {
                        existingCategories.insert(StorageUsageScreenComponent.Category(category))
                    }
                }
                
                if firstTime {
                    self.currentStats = stats
                    self.existingCategories = existingCategories
                }
                
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
                
                if firstTime {
                    self.peerItems = StoragePeerListPanelComponent.Items(items: peerItems)
                    self.state?.updated(transition: Transition(animation: .none).withUserData(AnimationHint(value: .firstStatsUpdate)))
                }
                
                class RenderResult {
                    var messages: [MessageId: Message] = [:]
                    var imageItems: [StorageFileListPanelComponent.Item] = []
                    var fileItems: [StorageFileListPanelComponent.Item] = []
                    var musicItems: [StorageFileListPanelComponent.Item] = []
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
                                    if let file = media as? TelegramMediaFile {
                                        if file.isSticker || file.isCustomEmoji {
                                        } else {
                                            matches = true
                                        }
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
                    guard let self, let component = self.component else {
                        completion()
                        return
                    }
                    
                    if !firstTime {
                        if let peer = component.peer, let controller = self.controller?() as? StorageUsageScreen, let childCompleted = controller.childCompleted {
                            let contextStats: StorageUsageStats = stats.peers[peer.id]?.stats ?? StorageUsageStats(categories: [:])
                            var totalSize: Int64 = 0
                            for (_, value) in contextStats.categories {
                                totalSize += value.size
                            }
                            
                            if totalSize == 0 {
                                childCompleted({ [weak self] in
                                    completion()
                                    
                                    if let self {
                                        self.controller?()?.dismiss(animated: true)
                                    }
                                })
                                return
                            } else {
                                childCompleted({})
                            }
                        }
                    }
                    
                    if !firstTime {
                        self.currentStats = stats
                        self.existingCategories = existingCategories
                        self.peerItems = StoragePeerListPanelComponent.Items(items: peerItems)
                    }
                    
                    self.currentMessages = result.messages
                    
                    self.imageItems = StorageFileListPanelComponent.Items(items: result.imageItems)
                    self.fileItems = StorageFileListPanelComponent.Items(items: result.fileItems)
                    self.musicItems = StorageFileListPanelComponent.Items(items: result.musicItems)
                    
                    if self.selectionState != nil {
                        if result.imageItems.isEmpty && result.fileItems.isEmpty && result.musicItems.isEmpty && peerItems.isEmpty {
                            self.selectionState = nil
                        } else {
                            self.selectionState = nil
                        }
                    }
                    
                    self.isClearing = false
                    
                    self.state?.updated(transition: Transition(animation: .none).withUserData(AnimationHint(value: .clearedItems)))
                    
                    completion()
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
            childController.childCompleted = { [weak self] completed in
                guard let self else {
                    return
                }
                self.reloadStats(firstTime: false, completion: {
                    completed()
                })
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
            
            let clearTitle: String
            if categories == self.existingCategories {
                clearTitle = presentationData.strings.StorageManagement_ClearAll
            } else {
                clearTitle = presentationData.strings.StorageManagement_ClearSelected
            }
            
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: clearTitle, color: .destructive, action: { [weak self, weak actionSheet] in
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
                
                self.isClearing = true
                self.state?.updated(transition: .immediate)
                
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
                    
                    self.reloadStats(firstTime: false, completion: { [weak self] in
                        guard let self else {
                            return
                        }
                        if totalSize != 0 {
                            self.reportClearedStorage(size: totalSize)
                        }
                    })
                })
            } else if !peers.isEmpty {
                self.isClearing = true
                self.state?.updated(transition: .immediate)
                
                var totalSize: Int64 = 0
                if let peerItems = self.peerItems {
                    for item in peerItems.items {
                        if peers.contains(item.peer.id) {
                            totalSize += item.size
                        }
                    }
                }
                
                let _ = (component.context.engine.resources.clearStorage(peerIds: peers)
                |> deliverOnMainQueue).start(completed: { [weak self] in
                    guard let self else {
                        return
                    }
                    
                    self.reloadStats(firstTime: false, completion: { [weak self] in
                        guard let self else {
                            return
                        }
                        if totalSize != 0 {
                            self.reportClearedStorage(size: totalSize)
                        }
                    })
                })
            } else if !messages.isEmpty {
                var messageItems: [Message] = []
                var totalSize: Int64 = 0
                
                let contextStats: StorageUsageStats
                if let peer = component.peer {
                    contextStats = self.currentStats?.peers[peer.id]?.stats ?? StorageUsageStats(categories: [:])
                } else {
                    contextStats = self.currentStats?.totalStats ?? StorageUsageStats(categories: [:])
                }
                
                for id in messages {
                    if let message = self.currentMessages[id] {
                        messageItems.append(message)
                        
                        for (_, value) in contextStats.categories {
                            if let size = value.messages[id] {
                                totalSize += size
                            }
                        }
                    }
                }
                
                self.isClearing = true
                self.state?.updated(transition: .immediate)
                
                let _ = (component.context.engine.resources.clearStorage(messages: messageItems)
                |> deliverOnMainQueue).start(completed: { [weak self] in
                    guard let self else {
                        return
                    }
                    
                    self.reloadStats(firstTime: false, completion: { [weak self] in
                        guard let self else {
                            return
                        }
                        
                        if totalSize != 0 {
                            self.reportClearedStorage(size: totalSize)
                        }
                    })
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
                    subItems.append(.custom(MultiplePeerAvatarsContextItem(context: context, peers: peerExceptions.prefix(3).map { EnginePeer($0.peer.peer) }, totalCount: peerExceptions.count, action: { c, _ in
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
    
    fileprivate var childCompleted: ((@escaping () -> Void) -> Void)?
    
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
    fileprivate let totalCount: Int
    fileprivate let action: (ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void) -> Void

    init(context: AccountContext, peers: [EnginePeer], totalCount: Int, action: @escaping (ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void) -> Void) {
        self.context = context
        self.peers = peers
        self.totalCount = totalCount
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
        let text: String = self.presentationData.strings.CacheEvictionMenu_CategoryExceptions(Int32(self.item.totalCount))
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

private class StorageUsageClearProgressOverlayNode: ASDisplayNode {
    private let presentationData: PresentationData
    
    private let blurredView: BlurredBackgroundView
    private let animationNode: AnimatedStickerNode
    private let progressTextNode: ImmediateTextNode
    private let descriptionTextNode: ImmediateTextNode
    private let progressBackgroundNode: ASDisplayNode
    private let progressForegroundNode: ASDisplayNode
    
    private let progressDisposable = MetaDisposable()
    
    private var validLayout: CGSize?
    
    init(presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.blurredView = BlurredBackgroundView(color: presentationData.theme.list.plainBackgroundColor.withMultipliedAlpha(0.7), enableBlur: true)
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()
        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "ClearCache"), width: 256, height: 256, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
        self.animationNode.visibility = true
        
        self.progressTextNode = ImmediateTextNode()
        self.progressTextNode.textAlignment = .center
        
        self.descriptionTextNode = ImmediateTextNode()
        self.descriptionTextNode.textAlignment = .center
        self.descriptionTextNode.maximumNumberOfLines = 0
        
        self.progressBackgroundNode = ASDisplayNode()
        self.progressBackgroundNode.backgroundColor = self.presentationData.theme.actionSheet.controlAccentColor.withMultipliedAlpha(0.2)
        self.progressBackgroundNode.cornerRadius = 3.0
        
        self.progressForegroundNode = ASDisplayNode()
        self.progressForegroundNode.backgroundColor = self.presentationData.theme.actionSheet.controlAccentColor
        self.progressForegroundNode.cornerRadius = 3.0
        
        super.init()
        
        self.view.addSubview(self.blurredView)
        self.addSubnode(self.animationNode)
        self.addSubnode(self.progressTextNode)
        self.addSubnode(self.descriptionTextNode)
        //self.addSubnode(self.progressBackgroundNode)
        //self.addSubnode(self.progressForegroundNode)
    }
    
    deinit {
        self.progressDisposable.dispose()
    }
    
    func setProgressSignal(_ signal: Signal<Float, NoError>) {
        self.progressDisposable.set((signal
        |> deliverOnMainQueue).start(next: { [weak self] progress in
            if let strongSelf = self {
                strongSelf.setProgress(progress)
            }
        }))
    }
    
    private var progress: Float = 0.0
    private func setProgress(_ progress: Float) {
        self.progress = progress
        
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .animated(duration: 0.5, curve: .linear))
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        transition.updateFrame(view: self.blurredView, frame: CGRect(origin: CGPoint(), size: size))
        self.blurredView.update(size: size, transition: transition)
        
        let inset: CGFloat = 24.0
        let progressHeight: CGFloat = 6.0
        let spacing: CGFloat = 16.0
        
        let imageSide = min(160.0, size.height - 30.0)
        let imageSize = CGSize(width: imageSide, height: imageSide)
        
        let animationFrame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: floorToScreenPixels((size.height - imageSize.height) / 2.0) - 50.0), size: imageSize)
        self.animationNode.frame = animationFrame
        self.animationNode.updateLayout(size: imageSize)
        
        let progressFrame = CGRect(x: inset, y: size.height - inset - progressHeight, width: size.width - inset * 2.0, height: progressHeight)
        self.progressBackgroundNode.frame = progressFrame
        let progressForegroundFrame = CGRect(x: inset, y: size.height - inset - progressHeight, width: floorToScreenPixels(progressFrame.width * CGFloat(self.progress)), height: progressHeight)
        if !self.progressForegroundNode.frame.origin.x.isZero {
            transition.updateFrame(node: self.progressForegroundNode, frame: progressForegroundFrame, beginWithCurrentState: true)
        } else {
            self.progressForegroundNode.frame = progressForegroundFrame
        }
        
        self.descriptionTextNode.attributedText = NSAttributedString(string: self.presentationData.strings.ClearCache_KeepOpenedDescription, font: Font.regular(15.0), textColor: self.presentationData.theme.actionSheet.secondaryTextColor)
        let descriptionTextSize = self.descriptionTextNode.updateLayout(CGSize(width: size.width - inset * 3.0, height: size.height))
        var descriptionTextFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - descriptionTextSize.width) / 2.0), y: animationFrame.maxY + 52.0), size: descriptionTextSize)
       
        self.progressTextNode.attributedText = NSAttributedString(string: self.presentationData.strings.ClearCache_NoProgress, font: Font.with(size: 17.0, design: .regular, weight: .semibold, traits: [.monospacedNumbers]), textColor: self.presentationData.theme.actionSheet.primaryTextColor)
        let progressTextSize = self.progressTextNode.updateLayout(size)
        var progressTextFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - progressTextSize.width) / 2.0), y: descriptionTextFrame.minY - spacing - progressTextSize.height), size: progressTextSize)
        
        let availableHeight = progressTextFrame.minY
        if availableHeight < 100.0 {
            let offset = availableHeight / 2.0 - spacing
            descriptionTextFrame = descriptionTextFrame.offsetBy(dx: 0.0, dy: -offset)
            progressTextFrame = progressTextFrame.offsetBy(dx: 0.0, dy: -offset)
            self.animationNode.alpha = 0.0
        } else {
            self.animationNode.alpha = 1.0
        }
        
        self.progressTextNode.frame = progressTextFrame
        self.descriptionTextNode.frame = descriptionTextFrame
    }
}
