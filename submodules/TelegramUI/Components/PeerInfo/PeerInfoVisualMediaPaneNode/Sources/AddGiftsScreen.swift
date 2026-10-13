import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import AccountContext
import ComponentFlow
import ViewControllerComponent
import BundleIconComponent
import BottomButtonPanelComponent
import ContextUI

final class AddGiftsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peerId: EnginePeer.Id
    let collectionId: Int32
    let remainingCount: Int32
    let profileGifts: ProfileGiftsContext

    init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        collectionId: Int32,
        remainingCount: Int32,
        profileGifts: ProfileGiftsContext
    ) {
        self.context = context
        self.peerId = peerId
        self.collectionId = collectionId
        self.remainingCount = remainingCount
        self.profileGifts = profileGifts
    }

    static func ==(lhs: AddGiftsScreenComponent, rhs: AddGiftsScreenComponent) -> Bool {
        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let backgroundView: UIView
        private let scrollView: ScrollView
        
        private var giftsListView: GiftsListView?
        
        private let buttonPanel = ComponentView<Empty>()
        private var bottomPanelHeight: CGFloat = 68.0
        
        private var isUpdating: Bool = false
        
        private var component: AddGiftsScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        override init(frame: CGRect) {
            self.backgroundView = UIView()
            
            self.scrollView = ScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.alwaysBounceVertical = true
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            self.updateScrolling(interactive: true, transition: .immediate)
        }
        
        private func updateScrolling(interactive: Bool = false, transition: ComponentTransition) {
            guard let environment = self.environment, let giftsListView = self.giftsListView else {
                return
            }
            let visibleBounds = self.scrollView.bounds.insetBy(dx: 0.0, dy: -10.0)
            let contentHeight = giftsListView.updateScrolling(topInset: environment.navigationHeight + 10.0, visibleBounds: visibleBounds, transition: transition)
        
            var contentSize = CGSize(width: self.scrollView.bounds.width, height: contentHeight)
            contentSize.height += environment.safeInsets.bottom
            contentSize.height = max(contentSize.height, self.scrollView.bounds.size.height)
            contentSize.height += self.bottomPanelHeight
            transition.setFrame(view: giftsListView, frame: CGRect(origin: CGPoint(), size: contentSize))
            
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            
            let bottomContentOffset = max(0.0, self.scrollView.contentSize.height - self.scrollView.contentOffset.y - self.scrollView.frame.height)
            if interactive, bottomContentOffset < 200.0 {
                self.giftsListView?.loadMore()
            }
        }
        
        func update(component: AddGiftsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let giftsListView: GiftsListView
            if let current = self.giftsListView {
                giftsListView = current
            } else {
                giftsListView = GiftsListView(context: component.context, peerId: component.peerId, profileGifts: component.profileGifts, giftsCollections: nil, canSelect: true, ignoreCollection: component.collectionId, remainingSelectionCount: component.remainingCount)
                giftsListView.onContentUpdated = { [weak self] in
                    guard let self else {
                        return
                    }
                    self.state?.updated(transition: .immediate)
                }
                giftsListView.selectionUpdated = { [weak self] in
                    guard let self else {
                        return
                    }
                    self.state?.updated(transition: .spring(duration: 0.4))
                }
                self.scrollView.addSubview(giftsListView)
                self.giftsListView = giftsListView
            }

            let environment = environment[EnvironmentType.self].value
            self.environment = environment
            
            self.component = component
            self.state = state
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let buttonString = environment.strings.AddGifts_AddGifts(Int32(max(1, giftsListView.selectedItems.count)))
            let bottomPanelSize = self.buttonPanel.update(
                transition: transition,
                component: AnyComponent(BottomButtonPanelComponent(
                    theme: environment.theme,
                    title: buttonString,
                    label: nil,
                    isEnabled: true,
                    insets: UIEdgeInsets(top: 0.0, left: sideInset, bottom: environment.safeInsets.bottom, right: sideInset),
                    action: { [weak self] in
                        guard let self, let controller = self.environment?.controller() as? AddGiftsScreen, let giftsListView = self.giftsListView else {
                            return
                        }
                        controller.completion(giftsListView.selectedItems)
                        controller.dismiss(animated: true)
                    }
                )),
                environment: {},
                containerSize: availableSize
            )
            self.bottomPanelHeight = bottomPanelSize.height

            let bottomPanelOffset: CGFloat = giftsListView.selectedItems.count > 0 ? 0.0 : bottomPanelSize.height
            if let buttonPanelView = self.buttonPanel.view {
                if buttonPanelView.superview == nil {
                    self.addSubview(buttonPanelView)
                }
                buttonPanelView.accessibilityElementsHidden = giftsListView.selectedItems.isEmpty
                transition.setFrame(view: buttonPanelView, frame: CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - bottomPanelSize.height + bottomPanelOffset), size: bottomPanelSize))
            }
            
            let visibleBounds = self.scrollView.bounds.insetBy(dx: 0.0, dy: -10.0)
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
            let _ = giftsListView.update(size: availableSize, sideInset: 0.0, bottomInset: max(environment.safeInsets.bottom, bottomPanelSize.height), deviceMetrics: environment.deviceMetrics, visibleHeight: availableSize.height, isScrollingLockedAtTop: false, expandProgress: 0.0, presentationData: presentationData, synchronous: false, visibleBounds: visibleBounds, transition: transition.containedViewLayoutTransition)
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: availableSize))
            self.backgroundView.backgroundColor = environment.theme.list.blocksBackgroundColor
            
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: .zero, size: availableSize))
            
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let r = super.hitTest(point, with: event)
            return r
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class AddGiftsScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private let collectionId: Int32
    fileprivate let completion: ([ProfileGiftsContext.State.StarGift]) -> Void
    
    private let profileGifts: ProfileGiftsContext
    
    private let filterButton: FilterHeaderButton
    
    public init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        collectionId: Int32,
        remainingCount: Int32,
        completion: @escaping ([ProfileGiftsContext.State.StarGift]) -> Void
    ) {
        self.context = context
        self.peerId = peerId
        self.collectionId = collectionId
        self.completion = completion
        
        self.profileGifts = ProfileGiftsContext(account: context.account, peerId: peerId)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.filterButton = FilterHeaderButton(presentationData: presentationData)
        
        super.init(context: context, component: AddGiftsScreenComponent(
            context: context,
            peerId: peerId,
            collectionId: collectionId,
            remainingCount: remainingCount,
            profileGifts: self.profileGifts
        ), navigationBarAppearance: .default, theme: .default, updatedPresentationData: nil)
        
        self.title = presentationData.strings.AddGifts_Title
        self.navigationPresentation = .modal
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? AddGiftsScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
                
        self.filterButton.contextAction = { [weak self] sourceNode, gesture in
            self?.presentContextMenu(sourceView: sourceNode.view, gesture: gesture)
        }
        self.filterButton.addTarget(self, action: #selector(self.filterPressed), forControlEvents: .touchUpInside)
        
        let closeButtonItem = UIBarButtonItem(title: "___close", style: .plain, target: self, action: #selector(self.cancelPressed))
        closeButtonItem.accessibilityLabel = presentationData.strings.Common_Close
        self.navigationItem.leftBarButtonItem = closeButtonItem
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: self.filterButton)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func presentContextMenu(sourceView: UIView, gesture: ContextGesture?) {
        let giftsContext = self.profileGifts
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let strings = presentationData.strings
        let items: Signal<ContextController.Items, NoError> = giftsContext.state
        |> map { state in
            var hasPinnedGifts = false
            for gift in state.gifts {
                if gift.pinnedToTop {
                    hasPinnedGifts = true
                    break
                }
            }
            return (state.filter, state.sorting, hasPinnedGifts)
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs -> Bool in
            let filterEquals = lhs.0 == rhs.0
            let sortingEquals = lhs.1 == rhs.1
            let hasPinnedGiftsEquals = lhs.2 == rhs.2
            return filterEquals && sortingEquals && hasPinnedGiftsEquals
        })
        |> map { [weak giftsContext] filter, sorting, hasPinnedGifts -> ContextController.Items in
            var items: [ContextMenuItem] = []
                        
            items.append(.action(ContextMenuActionItem(text: sorting == .date ? strings.PeerInfo_Gifts_SortByValue : strings.PeerInfo_Gifts_SortByDate, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: sorting == .date ? "Peer Info/SortValue" : "Peer Info/SortDate"), color: theme.contextMenu.primaryColor)
            }, action: { [weak giftsContext] _, f in
                f(.default)
                
                giftsContext?.updateSorting(sorting == .date ? .value : .date)
            })))
            
            items.append(.separator)
            
            let toggleFilter: (ProfileGiftsContext.Filters) -> Void = { [weak giftsContext] value in
                var updatedFilter = filter
                if updatedFilter.contains(value) {
                    updatedFilter.remove(value)
                } else {
                    updatedFilter.insert(value)
                }
                if !updatedFilter.contains(.unlimited) && !updatedFilter.contains(.limitedUpgradable) && !updatedFilter.contains(.limitedNonUpgradable) && !updatedFilter.contains(.unique) {
                    updatedFilter.insert(.unlimited)
                }
                if !updatedFilter.contains(.displayed) && !updatedFilter.contains(.hidden) {
                    if value == .displayed {
                        updatedFilter.insert(.hidden)
                    } else {
                        updatedFilter.insert(.displayed)
                    }
                }
                giftsContext?.updateFilter(updatedFilter)
            }
            
            let switchToFilter: (ProfileGiftsContext.Filters) -> Void = { [weak giftsContext] value in
                var updatedFilter = filter
                updatedFilter.remove(.unlimited)
                updatedFilter.remove(.limitedUpgradable)
                updatedFilter.remove(.limitedNonUpgradable)
                updatedFilter.remove(.unique)
                updatedFilter.insert(value)
                giftsContext?.updateFilter(updatedFilter)
            }
            
            let switchToVisiblityFilter: (ProfileGiftsContext.Filters) -> Void = { [weak giftsContext] value in
                var updatedFilter = filter
                updatedFilter.remove(.hidden)
                updatedFilter.remove(.displayed)
                updatedFilter.insert(value)
                giftsContext?.updateFilter(updatedFilter)
            }
            
            items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Unlimited, icon: { theme in
                return filter.contains(.unlimited) ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage()
            }, action: { _, f in
                toggleFilter(.unlimited)
            }, longPressAction: { _, f in
                switchToFilter(.unlimited)
            })))
            items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Limited, icon: { theme in
                return filter.contains(.limitedNonUpgradable) ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage()
            }, action: { _, f in
                toggleFilter(.limitedNonUpgradable)
            }, longPressAction: { _, f in
                switchToFilter(.limitedNonUpgradable)
            })))
            items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Upgradable, icon: { theme in
                return filter.contains(.limitedUpgradable) ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage()
            }, action: { _, f in
                toggleFilter(.limitedUpgradable)
            }, longPressAction: { _, f in
                switchToFilter(.limitedUpgradable)
            })))
            items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Unique, icon: { theme in
                return filter.contains(.unique) ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage()
            }, action: { _, f in
                toggleFilter(.unique)
            }, longPressAction: { _, f in
                switchToFilter(.unique)
            })))
            
            items.append(.separator)
            
            items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Displayed, icon: { theme in
                return filter.contains(.displayed) ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage()
            }, action: { _, f in
                toggleFilter(.displayed)
            }, longPressAction: { _, f in
                switchToVisiblityFilter(.displayed)
            })))
            items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Hidden, icon: { theme in
                return filter.contains(.hidden) ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage()
            }, action: { _, f in
                toggleFilter(.hidden)
            }, longPressAction: { _, f in
                switchToVisiblityFilter(.hidden)
            })))
        
            return ContextController.Items(content: .list(items))
        }
        
        let contextController = makeContextController(presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: self, sourceView: sourceView)), items: items, gesture: gesture)
        self.presentInGlobalOverlay(contextController)
    }
    
    deinit {
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    @objc private func filterPressed() {
        self.filterButton.contextAction?(self.filterButton.containerNode, nil)
    }
}

private final class FilterHeaderButton: HighlightableButtonNode {
    let referenceNode: ContextReferenceContentNode
    let containerNode: ContextControllerSourceNode
    private let icon = ComponentView<Empty>()
    
    var contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?

    init(presentationData: PresentationData) {
        self.referenceNode = ContextReferenceContentNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.animateScale = false

        super.init()

        self.isAccessibilityElement = true
        self.accessibilityLabel = presentationData.strings.Common_More
        self.accessibilityTraits = [.button]

        self.containerNode.addSubnode(self.referenceNode)
        self.addSubnode(self.containerNode)

        self.containerNode.shouldBegin = { [weak self] location in
            guard let strongSelf = self, let _ = strongSelf.contextAction else {
                return false
            }
            return true
        }
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.contextAction?(strongSelf.containerNode, gesture)
        }

        self.update(theme: presentationData.theme, strings: presentationData.strings)
    }

    func update(theme: PresentationTheme, strings: PresentationStrings) {
        let iconSize = self.icon.update(
            transition: .immediate,
            component: AnyComponent(
                BundleIconComponent(
                    name: "Peer Info/SortIcon",
                    tintColor: theme.chat.inputPanel.panelControlColor
                )
            ),
            environment: {},
            containerSize: CGSize(width: 44.0, height: 44.0)
        )
        if let view = self.icon.view {
            if view.superview == nil {
                view.isUserInteractionEnabled = false
                self.referenceNode.view.addSubview(view)
            }
            view.frame = CGRect(origin: CGPoint(x: 7.0, y: 7.0), size: iconSize)
        }
        
        self.containerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 44.0, height: 44.0))
        self.referenceNode.frame = self.containerNode.bounds
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 44.0, height: 44.0)
    }

    func onLayout() {
    }
}

private final class HeaderContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView

    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
