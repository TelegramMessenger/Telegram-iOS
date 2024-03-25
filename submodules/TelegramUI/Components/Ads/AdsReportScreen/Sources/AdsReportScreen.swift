import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import Markdown
import TextFormat
import TelegramPresentationData
import ViewControllerComponent
import SheetComponent
import BalancedTextComponent
import MultilineTextComponent
import ListSectionComponent
import ListActionItemComponent
import ItemListUI
import UndoUI
import AccountContext

private final class SheetPageContent: CombinedComponent {
    struct Item: Equatable {
        let title: String
        let subItems: [Item]
    }
    
    let context: AccountContext
    let title: String?
    let items: [Item]
    let action: (Item) -> Void
    let pop: () -> Void
    
    init(
        context: AccountContext,
        title: String?,
        items: [Item],
        action: @escaping (Item) -> Void,
        pop: @escaping () -> Void
    ) {
        self.context = context
        self.title = title
        self.items = items
        self.action = action
        self.pop = pop
    }
    
    static func ==(lhs: SheetPageContent, rhs: SheetPageContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        return true
    }
        
    static var body: Body {
        let background = Child(RoundedRectangle.self)
        let back = Child(Button.self)
        let title = Child(Text.self)
        let subtitle = Child(Text.self)
        let section = Child(ListSectionComponent.self)
        
        return { context in
            let component = context.component
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let theme = presentationData.theme
//            let strings = environment.strings
            
            let sideInset: CGFloat = 16.0
            
            var contentSize = CGSize(width: context.availableSize.width, height: 18.0)
                        
            let background = background.update(
                component: RoundedRectangle(color: theme.list.modalBlocksBackgroundColor, cornerRadius: 8.0),
                availableSize: CGSize(width: context.availableSize.width, height: 1000.0),
                transition: .immediate
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: background.size.height / 2.0))
            )
            
            let back = back.update(
                component: Button(
                    content: AnyComponent(
                        Text(text: "Cancel", font: Font.regular(17.0), color: theme.list.itemAccentColor)
                    ),
                    action: {
                        component.pop()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(back
                .position(CGPoint(x: sideInset + back.size.width / 2.0, y: contentSize.height + back.size.height / 2.0))
            )
            
            let title = title.update(
                component: Text(text: "Report Ad", font: Font.semibold(17.0), color: theme.list.itemPrimaryTextColor),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: .immediate
            )
            if let subtitleText = component.title {
                let subtitle = subtitle.update(
                    component: Text(text: subtitleText, font: Font.regular(13.0), color: theme.list.itemSecondaryTextColor),
                    availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                    transition: .immediate
                )
                context.add(title
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0 - 8.0))
                )
                contentSize.height += title.size.height
                context.add(subtitle
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + subtitle.size.height / 2.0 - 9.0))
                )
                contentSize.height += subtitle.size.height
                contentSize.height += 24.0
            } else {
                context.add(title
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0))
                )
                contentSize.height += title.size.height
                contentSize.height += 24.0
            }
            
            var items: [AnyComponentWithIdentity<Empty>] = []
            for item in component.items  {
                items.append(AnyComponentWithIdentity(id: item.title, component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: item.title,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))),
                    ], alignment: .left, spacing: 2.0)),
                    accessory: !item.subItems.isEmpty ? .arrow : nil,
                    action: { _ in
                        component.action(item)
                    }
                ))))
            }
            
            let section = section.update(
                component: ListSectionComponent(
                    theme: theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "WHAT IS WRONG WITH THIS AD?".uppercased(),
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .markdown(
                            text: "Learn more about [Telegram Ad Policies and Guidelines]().",
                            attributes: MarkdownAttributes(
                                body: MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: theme.list.freeTextColor),
                                bold: MarkdownAttributeSet(font: Font.semibold(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: theme.list.freeTextColor),
                                link: MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: theme.list.itemAccentColor),
                                linkAttribute: { _ in
                                    return nil
                                }
                            )
                        ),
                        maximumNumberOfLines: 0
                    )),
                    items: items
                ),
                environment: {},
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            context.add(section
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + section.size.height / 2.0))
            )
            contentSize.height += section.size.height
            contentSize.height += 54.0
            
            return contentSize
        }
    }
}

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let pts: Int
    let openMore: () -> Void
    let complete: () -> Void
    let dismiss: () -> Void
    let update: (Transition) -> Void
    
    init(
        context: AccountContext,
        pts: Int,
        openMore: @escaping () -> Void,
        complete: @escaping () -> Void,
        dismiss: @escaping () -> Void,
        update: @escaping (Transition) -> Void
    ) {
        self.context = context
        self.pts = pts
        self.openMore = openMore
        self.complete = complete
        self.dismiss = dismiss
        self.update = update
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.pts != rhs.pts {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var pushedItem: SheetPageContent.Item?
    }
    
    func makeState() -> State {
        return State()
    }
        
    static var body: Body {
//        let title = Child(BalancedTextComponent.self)
        let navigation = Child(NavigationStackComponent.self)
        
        return { context in
            let component = context.component
            let state = context.state
            let update = component.update
            
            var items: [AnyComponentWithIdentity<Empty>] = []
            items.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(
                SheetPageContent(
                    context: component.context,
                    title: nil,
                    items: [
                        SheetPageContent.Item(title: "I don't like it", subItems: []),
                        SheetPageContent.Item(title: "I don't want to see ads", subItems: []),
                        SheetPageContent.Item(title: "Destination doesn't match the ad", subItems: []),
                        SheetPageContent.Item(title: "Word choice or style", subItems: []),
                        SheetPageContent.Item(title: "Shocking or sexual content", subItems: []),
                        SheetPageContent.Item(title: "Hate speech or threats", subItems: []),
                        SheetPageContent.Item(title: "Scam or misleading", subItems: []),
                        SheetPageContent.Item(title: "Illegal or questionable products", subItems: [
                            SheetPageContent.Item(title: "Drugs, alcohol or tobacco", subItems: []),
                            SheetPageContent.Item(title: "Uncertified medicine or supplements", subItems: []),
                            SheetPageContent.Item(title: "Weapons or firearms", subItems: []),
                            SheetPageContent.Item(title: "Fake money", subItems: []),
                            SheetPageContent.Item(title: "Fake documents", subItems: []),
                            SheetPageContent.Item(title: "Malware, phishing, hacked accounts", subItems: []),
                            SheetPageContent.Item(title: "Human trafficking or exploitation", subItems: []),
                            SheetPageContent.Item(title: "Wild or restricted animals", subItems: []),
                            SheetPageContent.Item(title: "Gambling", subItems: [])
                        ]),
                        SheetPageContent.Item(title: "Copyright infringement", subItems: []),
                        SheetPageContent.Item(title: "Politics or religion", subItems: []),
                        SheetPageContent.Item(title: "Spam", subItems: [])
                    ],
                    action: { [weak state] item in
                        if !item.subItems.isEmpty {
                            state?.pushedItem = item
                            update(.spring(duration: 0.45))
                        } else {
                            component.complete()
                        }
                    },
                    pop: {
                        component.dismiss()
                    }
                )
            )))
            if let pushedItem = context.state.pushedItem {
                items.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(
                    SheetPageContent(
                        context: component.context,
                        title: pushedItem.title,
                        items: pushedItem.subItems.map {
                            SheetPageContent.Item(title: $0.title, subItems: [])
                        },
                        action: { item in
                            component.complete()
                        },
                        pop: { [weak state] in
                            state?.pushedItem = nil
                            update(.spring(duration: 0.45))
                        }
                    )
                )))
            }
            
            var contentSize = CGSize(width: context.availableSize.width, height: 0.0)
            let navigation = navigation.update(
                component: NavigationStackComponent(items: items),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: context.transition
            )
            context.add(navigation
                .position(CGPoint(x: context.availableSize.width / 2.0, y: navigation.size.height / 2.0))
                .clipsToBounds(true)
            )
            contentSize.height += navigation.size.height
                        
            return contentSize
        }
    }
}

private final class SheetContainerComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let openMore: () -> Void
    let complete: () -> Void
    
    init(
        context: AccountContext,
        openMore: @escaping () -> Void,
        complete: @escaping () -> Void
    ) {
        self.context = context
        self.openMore = openMore
        self.complete = complete
    }
    
    static func ==(lhs: SheetContainerComponent, rhs: SheetContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var pts: Int = 0
    }
    
    func makeState() -> State {
        return State()
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let state = context.state
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(SheetContent(
                        context: context.component.context,
                        pts: state.pts,
                        openMore: context.component.openMore,
                        complete: context.component.complete,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        },
                        update: { [weak state] transition in
                            state?.pts += 1
                            state?.updated(transition: transition)
                        }
                    )),
                    backgroundColor: .color(environment.theme.list.modalBlocksBackgroundColor),
                    followContentSizeChanges: true,
                    externalState: sheetExternalState,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                animateOut.invoke(Action { _ in
                                    if let controller = controller() {
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else {
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: max(environment.safeInsets.bottom, sheetExternalState.contentHeight), right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left, bottom: 0.0, right: environment.safeInsets.right),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: context.transition.containedViewLayoutTransition)
            }
            
            return context.availableSize
        }
    }
}


public final class AdsReportScreen: ViewControllerComponentContainer {
    private let context: AccountContext
        
    public init(
        context: AccountContext
    ) {
        self.context = context
                
        var completeImpl: (() -> Void)?
        super.init(
            context: context,
            component: SheetContainerComponent(
                context: context,
                openMore: {},
                complete: {
                    completeImpl?()
                }
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
        
        completeImpl = { [weak self] in
            guard let self else {
                return
            }
            let navigationController = self.navigationController
            self.dismissAnimated()
            
            Queue.mainQueue().after(0.4, {
                //TODO:localize
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                (navigationController?.viewControllers.last as? ViewController)?.present(UndoOverlayController(presentationData: presentationData, content: .actionSucceeded(title: nil, text: "We will review this ad to ensure it matches our [Ad Policies and Guidelines]().", cancel: nil, destructive: false), elevatedLayout: false, action: { _ in
                    return true
                }), in: .current)
            })
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}



//private final class NavigationContainer: UIView, UIGestureRecognizerDelegate {
//    var requestUpdate: ((Transition) -> Void)?
//    var requestPop: (() -> Void)?
//    var transitionFraction: CGFloat = 0.0
//    
//    private var panRecognizer: InteractiveTransitionGestureRecognizer?
//    
//    var isNavigationEnabled: Bool = false {
//        didSet {
//            self.panRecognizer?.isEnabled = self.isNavigationEnabled
//        }
//    }
//    
//    override init() {
//        super.init()
//        
//        self.clipsToBounds = true
//        
//        let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] point in
//            guard let strongSelf = self else {
//                return []
//            }
//            let _ = strongSelf
//            return [.right]
//        })
//        panRecognizer.delegate = self
//        self.view.addGestureRecognizer(panRecognizer)
//        self.panRecognizer = panRecognizer
//    }
//    
//    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//        return false
//    }
//    
//    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//        if let _ = otherGestureRecognizer as? InteractiveTransitionGestureRecognizer {
//            return false
//        }
//        if let _ = otherGestureRecognizer as? UIPanGestureRecognizer {
//            return true
//        }
//        return false
//    }
//    
//    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
//        switch recognizer.state {
//        case .began:
//            self.transitionFraction = 0.0
//        case .changed:
//            let distanceFactor: CGFloat = recognizer.translation(in: self.view).x / self.bounds.width
//            let transitionFraction = max(0.0, min(1.0, distanceFactor))
//            if self.transitionFraction != transitionFraction {
//                self.transitionFraction = transitionFraction
//                self.requestUpdate?(.immediate)
//            }
//        case .ended, .cancelled:
//            let distanceFactor: CGFloat = recognizer.translation(in: self.view).x / self.bounds.width
//            let transitionFraction = max(0.0, min(1.0, distanceFactor))
//            if transitionFraction > 0.2 {
//                self.transitionFraction = 0.0
//                self.requestPop?()
//            } else {
//                self.transitionFraction = 0.0
//                self.requestUpdate?(.spring(duration: 0.45))
//            }
//        default:
//            break
//        }
//    }
//}

final class NavigationStackComponent: Component {
    public let items: [AnyComponentWithIdentity<Empty>]
    
    public init(
        items: [AnyComponentWithIdentity<Empty>]
    ) {
        self.items = items
    }
    
    public static func ==(lhs: NavigationStackComponent, rhs: NavigationStackComponent) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        return true
    }
        
    private final class ItemView: UIView {
        let contents = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    public final class View: UIView {
        private var itemViews: [AnyHashable: ItemView] = [:]
        
        private var component: NavigationStackComponent?
        
        public override init(frame: CGRect) {
            super.init(frame: CGRect())
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
        }
                
        func update(component: NavigationStackComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            
            var contentHeight: CGFloat = 0.0
                        
            var validItemIds: [AnyHashable] = []
            struct ReadyItem {
                var index: Int
                var itemId: AnyHashable
                var itemView: ItemView
                var itemTransition: Transition
                var itemSize: CGSize
                
                init(index: Int, itemId: AnyHashable, itemView: ItemView, itemTransition: Transition, itemSize: CGSize) {
                    self.index = index
                    self.itemId = itemId
                    self.itemView = itemView
                    self.itemTransition = itemTransition
                    self.itemSize = itemSize
                }
            }
            
            var readyItems: [ReadyItem] = []
            for i in 0 ..< component.items.count {
                let item = component.items[i]
                let itemId = item.id
                validItemIds.append(itemId)
                
                let itemView: ItemView
                var itemTransition = transition
                if let current = self.itemViews[itemId] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = ItemView()
                    itemView.clipsToBounds = true
                    self.itemViews[itemId] = itemView
                    itemView.contents.parentState = state
                }
                
                let itemSize = itemView.contents.update(
                    transition: itemTransition,
                    component: item.component,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height)
                )
                
                readyItems.append(ReadyItem(
                    index: i,
                    itemId: itemId,
                    itemView: itemView,
                    itemTransition: itemTransition,
                    itemSize: itemSize
                ))
                
                if i == component.items.count - 1 {
                    contentHeight = itemSize.height
                }
            }
            
            for readyItem in readyItems.sorted(by: { $0.index < $1.index }) {
                let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: readyItem.itemSize)
                if let itemComponentView = readyItem.itemView.contents.view {
                    var isAdded = false
                    if itemComponentView.superview == nil {
                        isAdded = true
                        self.addSubview(itemComponentView)
                    }
                    readyItem.itemTransition.setFrame(view: readyItem.itemView, frame: itemFrame)
                    readyItem.itemTransition.setFrame(view: itemComponentView, frame: CGRect(origin: CGPoint(), size: itemFrame.size))
                    
                    if readyItem.index > 0 && isAdded {
                        transition.animatePosition(view: itemComponentView, from: CGPoint(x: itemFrame.width, y: 0.0), to: .zero, additive: true, completion: nil)
                    }
                }
            }
            
            var removedItemIds: [AnyHashable] = []
            for (id, _) in self.itemViews {
                if !validItemIds.contains(id) {
                    removedItemIds.append(id)
                }
            }
            for id in removedItemIds {
                guard let itemView = self.itemViews[id] else {
                    continue
                }
                var position = itemView.center
                position.x += itemView.bounds.width / 2.0
                transition.setPosition(view: itemView, position: position, completion: { _ in
                    itemView.removeFromSuperview()
                    self.itemViews.removeValue(forKey: id)
                })
            }
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
