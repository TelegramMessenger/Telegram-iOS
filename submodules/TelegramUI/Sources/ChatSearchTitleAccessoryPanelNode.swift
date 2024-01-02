import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ChatPresentationInterfaceState
import AccountContext
import ComponentFlow
import MultilineTextComponent
import PlainButtonComponent
import UIKitRuntimeUtils

final class ChatSearchTitleAccessoryPanelNode: ChatTitleAccessoryPanelNode, UIScrollViewDelegate {
    private final class Item {
        let tag: String
        
        init(tag: String) {
            self.tag = tag
        }
    }
    
    private final class ItemView: UIView {
        private let context: AccountContext
        private let item: Item
        private let action: (String) -> Void
        
        private let view = ComponentView<Empty>()
        
        init(context: AccountContext, item: Item, action: @escaping ((String) -> Void)) {
            self.context = context
            self.item = item
            self.action = action
            
            super.init(frame: CGRect())
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        func update(theme: PresentationTheme, height: CGFloat, transition: Transition) -> CGSize {
            let viewSize = self.view.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: self.item.tag, font: Font.regular(15.0), textColor: theme.rootController.navigationBar.primaryTextColor)),
                        insets: UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0)
                    )),
                    effectAlignment: .center,
                    minSize: CGSize(width: 0.0, height: height),
                    contentInsets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 8.0),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.action(self.item.tag)
                    },
                    isEnabled: true
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            if let componentView = self.view.view {
                if componentView.superview == nil {
                    self.addSubview(componentView)
                }
                transition.setFrame(view: componentView, frame: CGRect(origin: CGPoint(), size: viewSize))
            }
            return viewSize
        }
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private let context: AccountContext
    private var theme: PresentationTheme?
    private var strings: PresentationStrings?
    
    private let scrollView: ScrollView
    private let itemViews: [ItemView]
    
    init(context: AccountContext) {
        self.context = context
        
        self.scrollView = ScrollView(frame: CGRect())
        
        let tags: [String] = [
            "⭐️", "❤️", "✅", "⏰", "💭", "❗️", "👍", "👎", "🤩", "⚡️", "🤡", "👌", "👏"
        ]
        let items = tags.map {
            Item(tag: $0)
        }
        var itemAction: ((String) -> Void)?
        self.itemViews = items.map { item in
            return ItemView(context: context, item: item, action: { tag in
                itemAction?(tag)
            })
        }
        
        super.init()
        
        self.scrollView.delaysContentTouches = false
        self.scrollView.canCancelContentTouches = true
        self.scrollView.clipsToBounds = false
        self.scrollView.contentInsetAdjustmentBehavior = .never
        if #available(iOS 13.0, *) {
            self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        }
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.alwaysBounceHorizontal = false
        self.scrollView.alwaysBounceVertical = false
        self.scrollView.scrollsToTop = false
        self.scrollView.delegate = self
        
        self.view.addSubview(self.scrollView)
        
        self.scrollView.disablesInteractiveTransitionGestureRecognizer = true
        
        for itemView in self.itemViews {
            self.scrollView.addSubview(itemView)
        }
        
        itemAction = { [weak self] tag in
            guard let self, let interfaceInteraction = self.interfaceInteraction else {
                return
            }
            interfaceInteraction.beginMessageSearch(.tag(tag), "")
        }
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        if interfaceState.strings !== self.strings {
            self.strings = interfaceState.strings
        }
        
        if interfaceState.theme !== self.theme {
            self.theme = interfaceState.theme
        }
        
        let panelHeight: CGFloat = 33.0
        
        let containerInsets = UIEdgeInsets(top: 0.0, left: leftInset + 2.0, bottom: 0.0, right: rightInset + 2.0)
        let itemSpacing: CGFloat = 2.0
        
        var contentSize = CGSize(width: 0.0, height: panelHeight)
        contentSize.width += containerInsets.left
        
        var isFirst = true
        for itemView in self.itemViews {
            if isFirst {
                isFirst = false
            } else {
                contentSize.width += itemSpacing
            }
            
            let itemSize = itemView.update(theme: interfaceState.theme, height: panelHeight, transition: .immediate)
            itemView.frame = CGRect(origin: CGPoint(x: contentSize.width, y: 0.0), size: itemSize)
            contentSize.width += itemSize.width
        }
        
        contentSize.width += containerInsets.right
        
        let scrollSize = CGSize(width: width, height: contentSize.height)
        if self.scrollView.bounds.size != scrollSize {
            self.scrollView.frame = CGRect(origin: CGPoint(x: 0.0, y: -5.0), size: scrollSize)
        }
        if self.scrollView.contentSize != contentSize {
            self.scrollView.contentSize = contentSize
        }
        
        return LayoutResult(backgroundHeight: panelHeight, insetHeight: panelHeight, hitTestSlop: 0.0)
    }
}
