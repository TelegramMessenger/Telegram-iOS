import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AccountContext
import PresentationDataUtils
import TelegramCore

public final class MessageFeeHeaderPanelComponent: Component {
    public struct Info: Equatable {
        public let value: Int64
        public let peer: EnginePeer

        public init(value: Int64, peer: EnginePeer) {
            self.value = value
            self.peer = peer
        }
    }
    
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let info: Info
    public let removeFee: () -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        info: Info,
        removeFee: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.info = info
        self.removeFee = removeFee
    }
    
    public static func ==(lhs: MessageFeeHeaderPanelComponent, rhs: MessageFeeHeaderPanelComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.info != rhs.info {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var panel: ChatFeePanelNode?
        
        private var component: MessageFeeHeaderPanelComponent?
        private weak var state: EmptyComponentState?
        
        public override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func update(component: MessageFeeHeaderPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let panel: ChatFeePanelNode
            if let current = self.panel {
                panel = current
            } else {
                panel = ChatFeePanelNode(
                    context: component.context,
                    removeFee: component.removeFee
                )
                self.panel = panel
                self.addSubview(panel.view)
            }
            
            let height = panel.updateLayout(
                width: availableSize.width,
                theme: component.theme,
                strings: component.strings,
                info: component.info,
                transition: transition.containedViewLayoutTransition
            )
            let size = CGSize(width: availableSize.width, height: height)
            let panelFrame = CGRect(origin: CGPoint(), size: size)
            transition.setFrame(view: panel.view, frame: panelFrame)
            
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
