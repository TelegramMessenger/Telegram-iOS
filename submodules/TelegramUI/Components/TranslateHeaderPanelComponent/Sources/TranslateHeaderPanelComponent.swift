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

public final class TranslateHeaderPanelComponent: Component {
    public struct Info: Equatable {
        public let isPremium: Bool
        public let isActive: Bool
        public let fromLang: String
        public let toLang: String?
        public let peer: EnginePeer?
        
        public init(isPremium: Bool, isActive: Bool, fromLang: String, toLang: String?, peer: EnginePeer?) {
            self.isPremium = isPremium
            self.isActive = isActive
            self.fromLang = fromLang
            self.toLang = toLang
            self.peer = peer
        }
    }
    
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let info: Info
    public let close: () -> Void
    public let toggle: () -> Void
    public let changeLanguage: (String) -> Void
    public let addDoNotTranslateLanguage: (String) -> Void
    public let controller: () -> ViewController?
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        info: Info,
        close: @escaping () -> Void,
        toggle: @escaping () -> Void,
        changeLanguage: @escaping (String) -> Void,
        addDoNotTranslateLanguage: @escaping (String) -> Void,
        controller: @escaping () -> ViewController?
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.info = info
        self.close = close
        self.toggle = toggle
        self.changeLanguage = changeLanguage
        self.addDoNotTranslateLanguage = addDoNotTranslateLanguage
        self.controller = controller
    }
    
    public static func ==(lhs: TranslateHeaderPanelComponent, rhs: TranslateHeaderPanelComponent) -> Bool {
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
        private var panel: ChatTranslationPanelNode?
        
        private var component: TranslateHeaderPanelComponent?
        private weak var state: EmptyComponentState?
        
        public override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func update(component: TranslateHeaderPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let panel: ChatTranslationPanelNode
            if let current = self.panel {
                panel = current
            } else {
                panel = ChatTranslationPanelNode(
                    context: component.context,
                    close: component.close,
                    toggle: component.toggle,
                    changeLanguage: component.changeLanguage,
                    addDoNotTranslateLanguage: component.addDoNotTranslateLanguage,
                    controller: component.controller
                )
                self.panel = panel
                self.addSubview(panel.view)
            }
            
            let size = CGSize(width: availableSize.width, height: 40.0)
            let panelFrame = CGRect(origin: CGPoint(), size: size)
            transition.setFrame(view: panel.view, frame: panelFrame)
            let _ = panel.updateLayout(
                width: panelFrame.width,
                info: component.info,
                theme: component.theme,
                strings: component.strings,
                transition: transition.containedViewLayoutTransition
            )
            
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
