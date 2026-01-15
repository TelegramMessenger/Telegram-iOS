import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import ChatPresentationInterfaceState
import AsyncDisplayKit
import AccountContext

open class ChatTitleAccessoryPanelNode: ASDisplayNode {
    public typealias LayoutResult = ChatControllerCustomNavigationPanelNodeLayoutResult
    
    open var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    open func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        preconditionFailure()
    }
}

public final class LegacyChatHeaderPanelComponent: Component {
    public let panelNode: ChatTitleAccessoryPanelNode
    public let interfaceState: ChatPresentationInterfaceState
    
    public init(
        panelNode: ChatTitleAccessoryPanelNode,
        interfaceState: ChatPresentationInterfaceState
    ) {
        self.panelNode = panelNode
        self.interfaceState = interfaceState
    }
    
    public static func ==(lhs: LegacyChatHeaderPanelComponent, rhs: LegacyChatHeaderPanelComponent) -> Bool {
        if lhs.panelNode !== rhs.panelNode {
            return false
        }
        if lhs.interfaceState != rhs.interfaceState {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var component: LegacyChatHeaderPanelComponent?
        private weak var state: EmptyComponentState?
        
        public override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func update(component: LegacyChatHeaderPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            self.state = state

            if previousComponent?.panelNode !== component.panelNode {
                previousComponent?.panelNode.view.removeFromSuperview()
                self.addSubview(component.panelNode.view)
            }
            
            let result = component.panelNode.updateLayout(
                width: availableSize.width,
                leftInset: 0.0,
                rightInset: 0.0,
                transition: transition.containedViewLayoutTransition,
                interfaceState: component.interfaceState
            )
            let size = CGSize(width: availableSize.width, height: result.backgroundHeight)
            let panelFrame = CGRect(origin: CGPoint(), size: size)
            transition.setFrame(view: component.panelNode.view, frame: panelFrame)
            
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
