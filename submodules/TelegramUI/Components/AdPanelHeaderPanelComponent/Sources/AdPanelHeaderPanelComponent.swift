import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AccountContext
import TelegramCore
import SwiftSignalKit
import Postbox
import PresentationDataUtils
import ContextUI
import AsyncDisplayKit

public final class AdPanelHeaderPanelComponent: Component {
    public struct Info: Equatable {
        public let message: EngineMessage
        
        public init(message: EngineMessage) {
            self.message = message
        }
    }
    
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let info: Info
    public let action: (EngineMessage) -> Void
    public let contextAction: (EngineMessage, ASDisplayNode, ContextGesture?) -> Void
    public let close: () -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        info: Info,
        action: @escaping (EngineMessage) -> Void,
        contextAction: @escaping (EngineMessage, ASDisplayNode, ContextGesture?) -> Void,
        close: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.info = info
        self.action = action
        self.contextAction = contextAction
        self.close = close
    }
    
    public static func ==(lhs: AdPanelHeaderPanelComponent, rhs: AdPanelHeaderPanelComponent) -> Bool {
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
        private var panel: ChatAdPanelNode?
        
        private var component: AdPanelHeaderPanelComponent?
        private weak var state: EmptyComponentState?
        
        public var message: EngineMessage? {
            return self.component?.info.message
        }
        
        public override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func update(component: AdPanelHeaderPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let panel: ChatAdPanelNode
            if let current = self.panel {
                panel = current
            } else {
                panel = ChatAdPanelNode(
                    context: component.context,
                    action: component.action,
                    contextAction: component.contextAction,
                    close: component.close
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
