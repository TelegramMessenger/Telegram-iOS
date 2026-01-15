import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AccountContext
import TelegramCore
import GlobalControlPanelsContext
import SwiftSignalKit
import Postbox
import PresentationDataUtils

public final class GroupCallHeaderPanelComponent: Component {
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let data: GlobalControlPanelsContext.GroupCall
    public let onTapAction: () -> Void
    public let onNotifyScheduledTapAction: () -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        data: GlobalControlPanelsContext.GroupCall,
        onTapAction: @escaping () -> Void,
        onNotifyScheduledTapAction: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.data = data
        self.onTapAction = onTapAction
        self.onNotifyScheduledTapAction = onNotifyScheduledTapAction
    }
    
    public static func ==(lhs: GroupCallHeaderPanelComponent, rhs: GroupCallHeaderPanelComponent) -> Bool {
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
        private var panel: GroupCallNavigationAccessoryPanel?
        
        private var component: GroupCallHeaderPanelComponent?
        private weak var state: EmptyComponentState?
        
        public override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func update(component: GroupCallHeaderPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme

            self.component = component
            self.state = state
            
            let presentationData = component.context.sharedContext.currentPresentationData.with ({ $0 }).withUpdated(theme: component.theme)
            
            let panel: GroupCallNavigationAccessoryPanel
            if let current = self.panel {
                panel = current
            } else {
                panel = GroupCallNavigationAccessoryPanel(
                    context: component.context,
                    presentationData: presentationData,
                    tapAction: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.onTapAction()
                    },
                    notifyScheduledTapAction: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.onNotifyScheduledTapAction()
                    }
                )
                self.panel = panel
                self.addSubview(panel.view)
            }
            
            let size = CGSize(width: availableSize.width, height: 50.0)
            let panelFrame = CGRect(origin: CGPoint(), size: size)
            transition.setFrame(view: panel.view, frame: panelFrame)
            panel.updateLayout(size: panelFrame.size, leftInset: 0.0, rightInset: 0.0, isHidden: false, transition: transition.containedViewLayoutTransition)
            panel.update(data: component.data)
            
            if themeUpdated {
                panel.updatePresentationData(presentationData)
            }
            
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
