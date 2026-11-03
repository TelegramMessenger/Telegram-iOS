import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext
import GlobalControlPanelsContext
import ComponentFlow
import ComponentDisplayAdapters

public final class ChatListHeaderNoticeComponent: Component {
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let data: GlobalControlPanelsContext.ChatListNotice
    public let activateAction: (GlobalControlPanelsContext.ChatListNotice) -> Void
    public let dismissAction: (GlobalControlPanelsContext.ChatListNotice) -> Void
    public let selectAction: (GlobalControlPanelsContext.ChatListNotice, Bool) -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        data: GlobalControlPanelsContext.ChatListNotice,
        activateAction: @escaping (GlobalControlPanelsContext.ChatListNotice) -> Void,
        dismissAction: @escaping (GlobalControlPanelsContext.ChatListNotice) -> Void,
        selectAction: @escaping (GlobalControlPanelsContext.ChatListNotice, Bool) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.data = data
        self.activateAction = activateAction
        self.dismissAction = dismissAction
        self.selectAction = selectAction
    }
    
    public static func ==(lhs: ChatListHeaderNoticeComponent, rhs: ChatListHeaderNoticeComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.data != rhs.data {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var panel: ChatListNoticeItemNode?
        
        private var component: ChatListHeaderNoticeComponent?
        private weak var state: EmptyComponentState?
        
        public override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = recognizer.state {
                component.activateAction(component.data)
            }
        }
        
        func update(component: ChatListHeaderNoticeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let itemNode: ChatListNoticeItemNode
            if let current = self.panel {
                itemNode = current
            } else {
                itemNode = ChatListNoticeItemNode()
                self.panel = itemNode
                self.addSubview(itemNode.view)
            }
            
            let item = ChatListNoticeItem(
                context: component.context,
                theme: component.theme,
                strings: component.strings,
                notice: component.data,
                action: { [weak self] action in
                    guard let self, let component = self.component else {
                        return
                    }
                    switch action {
                    case .activate:
                        component.activateAction(component.data)
                    case .hide:
                        component.dismissAction(component.data)
                    case let .buttonChoice(isPositive):
                        component.selectAction(component.data, isPositive)
                    }
                }
            )
            let (nodeLayout, apply) = itemNode.asyncLayout()(item, ListViewItemLayoutParams(
                width: availableSize.width,
                leftInset: 0.0,
                rightInset: 0.0,
                availableHeight: 10000.0,
                isStandalone: true
            ), false)
            
            let size = CGSize(width: availableSize.width, height: nodeLayout.contentSize.height)
            let panelFrame = CGRect(origin: CGPoint(), size: size)
            transition.setFrame(view: itemNode.view, frame: panelFrame)
            apply()
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
