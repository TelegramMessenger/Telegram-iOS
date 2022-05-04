import Foundation
import UIKit
import ComponentFlow

public final class UndoPanelContainerComponent: Component {
    let push: ActionSlot<UndoPanelComponent>
    
    public init(push: ActionSlot<UndoPanelComponent>) {
        self.push = push
    }

    public static func ==(lhs: UndoPanelContainerComponent, rhs: UndoPanelContainerComponent) -> Bool {
        if lhs.push != rhs.push {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var topPanel: UndoPanelComponent?
        private var topPanelView: ComponentHostView<Empty>?
        
        private var nextPanel: UndoPanelComponent?
        
        public func update(component: UndoPanelContainerComponent, availableSize: CGSize, state: EmptyComponentState, transition: Transition) -> CGSize {
            component.push.connect { [weak self, weak state] panel in
                guard let strongSelf = self, let state = state else {
                    return
                }
                
                strongSelf.nextPanel = panel
                state.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
            }
            
            var animateTopPanelIn = false
            var topPanelTransition = transition
            if let nextPanel = self.nextPanel {
                self.nextPanel = nil
                self.topPanel = nextPanel
                
                if let topPanelView = self.topPanelView {
                    self.topPanelView = nil
                    
                    transition.withAnimationIfAnimated(.curve(duration: 0.3, curve: .easeInOut)).setAlpha(view: topPanelView, alpha: 0.0, completion: { [weak topPanelView] _ in
                        topPanelView?.removeFromSuperview()
                    })
                }
                
                let topPanelView = ComponentHostView<Empty>()
                self.topPanelView = topPanelView
                self.addSubview(topPanelView)
                
                topPanelTransition = topPanelTransition.withAnimation(.none)
                animateTopPanelIn = true
            }
            
            if let topPanel = self.topPanel, let topPanelView = self.topPanelView {
                let topPanelSize = topPanelView.update(
                    transition: topPanelTransition,
                    component: AnyComponent(topPanel),
                    environment: {},
                    containerSize: availableSize
                )
                
                if animateTopPanelIn {
                    let _ = transition.withAnimationIfAnimated(.curve(duration: 0.3, curve: .easeInOut))
                }
                
                return CGSize(width: availableSize.width, height: topPanelSize.height)
            }
            
            return CGSize(width: availableSize.width, height: 0.0)
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, transition: transition)
    }
}
