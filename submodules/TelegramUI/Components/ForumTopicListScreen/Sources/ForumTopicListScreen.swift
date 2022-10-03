import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import AnimationCache
import MultiAnimationRenderer
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import Postbox
import TelegramCore

private final class ForumTopicListItemComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let item: ForumChannelTopics.Item
    let action: () -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        item: ForumChannelTopics.Item,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.item = item
        self.action = action
    }
    
    static func ==(lhs: ForumTopicListItemComponent, rhs: ForumTopicListItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.item != rhs.item {
            return false
        }
        return true
    }
    
    final class View: HighlightTrackingButton {
        private var highlightedBackgroundLayer: SimpleLayer?
        private let title: ComponentView<Empty>
        
        private var component: ForumTopicListItemComponent?
        
        override init(frame: CGRect) {
            self.title = ComponentView()
            
            super.init(frame: frame)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.highligthedChanged = { [weak self] highlighted in
                if let self, let component = self.component {
                    if highlighted {
                        if let superview = self.superview {
                            superview.bringSubviewToFront(self)
                        }
                        let highlightedBackgroundLayer: SimpleLayer
                        if let current = self.highlightedBackgroundLayer {
                            highlightedBackgroundLayer = current
                        } else {
                            highlightedBackgroundLayer = SimpleLayer()
                            self.highlightedBackgroundLayer = highlightedBackgroundLayer
                            highlightedBackgroundLayer.backgroundColor = component.theme.list.itemHighlightedBackgroundColor.cgColor
                            highlightedBackgroundLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: self.bounds.width, height: self.bounds.height + UIScreenPixel))
                            self.layer.insertSublayer(highlightedBackgroundLayer, at: 0)
                        }
                        highlightedBackgroundLayer.removeAllAnimations()
                        highlightedBackgroundLayer.opacity = 1.0
                    } else {
                        if let highlightedBackgroundLayer = self.highlightedBackgroundLayer {
                            self.highlightedBackgroundLayer = nil
                            highlightedBackgroundLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak highlightedBackgroundLayer] _ in
                                highlightedBackgroundLayer?.removeFromSuperlayer()
                            })
                        }
                    }
                }
            }
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func pressed() {
            self.component?.action()
        }
        
        func update(component: ForumTopicListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(Text(
                    text: component.item.info.title,
                    font: Font.regular(17.0),
                    color: component.theme.list.itemPrimaryTextColor
                )),
                environment: {},
                containerSize: availableSize
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                    titleView.isUserInteractionEnabled = false
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: 11.0, y: floor((availableSize.height - titleSize.height) / 2.0)), size: titleSize))
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ForumTopicListComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let items: [ForumChannelTopics.Item]
    let navigationHeight: CGFloat
    let action: (ForumChannelTopics.Item) -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        items: [ForumChannelTopics.Item],
        navigationHeight: CGFloat,
        action: @escaping (ForumChannelTopics.Item) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.items = items
        self.navigationHeight = navigationHeight
        self.action = action
    }
    
    static func ==(lhs: ForumTopicListComponent, rhs: ForumTopicListComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.navigationHeight != rhs.navigationHeight {
            return false
        }
        return true
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private struct ItemLayout {
            let containerSize: CGSize
            let itemHeight: CGFloat
            let contentSize: CGSize
            let itemsInsets: UIEdgeInsets
            
            init(containerSize: CGSize, navigationHeight: CGFloat, itemCount: Int) {
                self.itemHeight = 44.0
                self.containerSize = containerSize
                self.itemsInsets = UIEdgeInsets(top: navigationHeight, left: 0.0, bottom: 0.0, right: 0.0)
                self.contentSize = CGSize(width: containerSize.width, height: self.itemsInsets.top + self.itemsInsets.bottom + CGFloat(itemCount) * self.itemHeight)
            }
            
            func frame(at index: Int) -> CGRect {
                return CGRect(origin: CGPoint(x: 0.0, y: self.itemsInsets.top + CGFloat(index) * self.itemHeight), size: CGSize(width: self.containerSize.width, height: self.itemHeight))
            }
        }
        
        private final class ItemView {
            let host: ComponentView<Empty>
            let separatorLayer: SimpleLayer
            
            init() {
                self.host = ComponentView()
                self.separatorLayer = SimpleLayer()
            }
        }
        
        private let scrollView: UIScrollView
        
        private var component: ForumTopicListComponent?
        private var itemLayout: ItemLayout?
        
        private var ignoreScrolling: Bool = false
        private var visibleItemViews: [Int64: ItemView] = [:]
        
        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            
            super.init(frame: frame)
            
            self.scrollView.layer.anchorPoint = CGPoint()
            self.scrollView.delaysContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            self.scrollView.canCancelContentTouches = true
            
            self.addSubview(self.scrollView)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateVisibleItems(transition: .immediate, synchronous: false)
            }
        }
        
        private func updateVisibleItems(transition: Transition, synchronous: Bool) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            var validIds = Set<Int64>()
            let visibleBounds = self.scrollView.bounds
            for index in 0 ..< component.items.count {
                let itemFrame = itemLayout.frame(at: index)
                if !visibleBounds.intersects(itemFrame) {
                    continue
                }
                
                let item = component.items[index]
                validIds.insert(item.id)
                
                let itemView: ItemView
                var itemTransition = transition
                if let current = self.visibleItemViews[item.id] {
                    itemView = current
                } else {
                    itemTransition = .immediate
                    itemView = ItemView()
                    self.visibleItemViews[item.id] = itemView
                }
                
                let id = item.id
                let _ = itemView.host.update(
                    transition: itemTransition,
                    component: AnyComponent(ForumTopicListItemComponent(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        item: item,
                        action: { [weak self] in
                            guard let strongSelf = self, let component = strongSelf.component else {
                                return
                            }
                            for item in component.items {
                                if item.id == id {
                                    component.action(item)
                                    break
                                }
                            }
                        }
                    )),
                    environment: {},
                    containerSize: itemFrame.size
                )
                if let itemComponentView = itemView.host.view {
                    if itemComponentView.superview == nil {
                        self.scrollView.addSubview(itemComponentView)
                        self.scrollView.layer.addSublayer(itemView.separatorLayer)
                    }
                    itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                    
                    let separatorInset: CGFloat
                    if index == component.items.count - 1 {
                        separatorInset = 0.0
                    } else {
                        separatorInset = 16.0
                    }
                    itemView.separatorLayer.backgroundColor = component.theme.list.itemPlainSeparatorColor.cgColor
                    itemTransition.setFrame(layer: itemView.separatorLayer, frame: CGRect(origin: CGPoint(x: separatorInset, y: itemFrame.maxY - UIScreenPixel), size: CGSize(width: itemLayout.contentSize.width - separatorInset, height: UIScreenPixel)))
                }
            }
            
            var removedIds: [Int64] = []
            for (id, itemView) in self.visibleItemViews {
                if !validIds.contains(id) {
                    itemView.host.view?.removeFromSuperview()
                    itemView.separatorLayer.removeFromSuperlayer()
                    removedIds.append(id)
                }
            }
            for id in removedIds {
                self.visibleItemViews.removeValue(forKey: id)
            }
        }
        
        func update(component: ForumTopicListComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            
            let itemLayout = ItemLayout(containerSize: availableSize, navigationHeight: component.navigationHeight, itemCount: component.items.count)
            self.itemLayout = itemLayout
            
            self.ignoreScrolling = true
            self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            if self.scrollView.contentSize != itemLayout.contentSize {
                self.scrollView.contentSize = itemLayout.contentSize
            }
            if self.scrollView.scrollIndicatorInsets != itemLayout.itemsInsets {
                self.scrollView.scrollIndicatorInsets = itemLayout.itemsInsets
            }
            self.ignoreScrolling = false
            
            self.updateVisibleItems(transition: transition, synchronous: false)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class ForumTopicListScreen: ViewController {
    private final class Node: ViewControllerTracingNode {
        private weak var controller: ForumTopicListScreen?
        
        private let context: AccountContext
        private let id: EnginePeer.Id
        private var presentationData: PresentationData
        
        private let topicList: ComponentView<Empty>
        
        private let forumChannelContext: ForumChannelTopics
        private var stateDisposable: Disposable?
        private var currentState: ForumChannelTopics.State?
        
        private var currentLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
        
        init(controller: ForumTopicListScreen, context: AccountContext, id: EnginePeer.Id) {
            self.controller = controller
            
            self.context = context
            self.id = id
            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            self.topicList = ComponentView()
            
            self.forumChannelContext = ForumChannelTopics(account: self.context.account, peerId: self.id)
            
            super.init()
            
            self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            
            self.stateDisposable = (self.forumChannelContext.state
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.currentState = state
                strongSelf.update(transition: .immediate)
            })
        }
        
        deinit {
            self.stateDisposable?.dispose()
        }
        
        func createPressed() {
        }
        
        private func update(transition: Transition) {
            if let currentLayout = self.currentLayout {
                self.containerLayoutUpdated(layout: currentLayout.layout, navigationHeight: currentLayout.navigationHeight, transition: transition)
            }
        }
        
        func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: Transition) {
            self.currentLayout = (layout, navigationHeight)
            
            let _ = self.topicList.update(
                transition: transition,
                component: AnyComponent(ForumTopicListComponent(
                    context: self.context,
                    theme: self.presentationData.theme,
                    strings: self.presentationData.strings,
                    items: self.currentState?.items ?? [],
                    navigationHeight: navigationHeight,
                    action: { [weak self] item in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.controller?.openTopic(item)
                    }
                )),
                environment: {},
                containerSize: layout.size
            )
            if let topicListView = self.topicList.view {
                if topicListView.superview == nil {
                    if let navigationBar = self.controller?.navigationBar {
                        self.view.insertSubview(topicListView, belowSubview: navigationBar.view)
                    } else {
                        self.view.addSubview(topicListView)
                    }
                }
                transition.setFrame(view: topicListView, frame: CGRect(origin: CGPoint(), size: layout.size))
            }
        }
    }
    
    private var node: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    private let id: EnginePeer.Id
    private var presentationData: PresentationData
    private let openTopic: (ForumChannelTopics.Item) -> Void

    public init(context: AccountContext, id: EnginePeer.Id, openTopic: @escaping (ForumChannelTopics.Item) -> Void) {
        self.context = context
        self.id = id
        self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        self.openTopic = openTopic
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        //TODO:localize
        self.title = "Forum"
        
        self.navigationItem.setRightBarButton(UIBarButtonItem(title: "Create", style: .plain, target: self, action: #selector(self.createPressed)), animated: false)
    }
    
    public required init(coder aDecoder: NSCoder) {
        preconditionFailure()
    }
    
    @objc private func createPressed() {
        self.node.createPressed()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self, context: self.context, id: self.id)
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.node.containerLayoutUpdated(layout: layout, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: Transition(transition))
    }
}
