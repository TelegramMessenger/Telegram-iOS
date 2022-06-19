import Foundation
import UIKit
import Display
import ComponentFlow
import PagerComponent
import TelegramPresentationData
import TelegramCore
import Postbox

final class EntityKeyboardTopContainerPanelComponent: Component {
    typealias EnvironmentType = PagerComponentPanelEnvironment
    
    let theme: PresentationTheme
    
    init(
        theme: PresentationTheme
    ) {
        self.theme = theme
    }
    
    static func ==(lhs: EntityKeyboardTopContainerPanelComponent, rhs: EntityKeyboardTopContainerPanelComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        
        return true
    }
    
    final class View: UIView {
        private var panelViews: [AnyHashable: ComponentHostView<Empty>] = [:]
        
        private var component: EntityKeyboardTopContainerPanelComponent?
        private var panelEnvironment: PagerComponentPanelEnvironment?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: EntityKeyboardTopContainerPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            let intrinsicHeight: CGFloat = 41.0
            let height = intrinsicHeight
            
            let panelEnvironment = environment[PagerComponentPanelEnvironment.self].value
            
            var transitionOffsetFraction: CGFloat = 0.0
            if case .none = transition.animation {
            } else if let previousPanelEnvironment = self.panelEnvironment, let previousActiveContentId = previousPanelEnvironment.activeContentId, let activeContentId = panelEnvironment.activeContentId, previousActiveContentId != activeContentId {
                if let previousIndex = panelEnvironment.contentTopPanels.firstIndex(where: { $0.id == previousActiveContentId }), let index = panelEnvironment.contentTopPanels.firstIndex(where: { $0.id == activeContentId }), previousIndex != index {
                    if index < previousIndex {
                        transitionOffsetFraction = -1.0
                    } else {
                        transitionOffsetFraction = 1.0
                    }
                }
            }
            
            self.component = component
            self.panelEnvironment = panelEnvironment
            self.state = state
            
            var validPanelIds = Set<AnyHashable>()
            let visibleBounds = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: intrinsicHeight))
            if let centralId = panelEnvironment.activeContentId, let centralIndex = panelEnvironment.contentTopPanels.firstIndex(where: { $0.id == centralId }) {
                for index in 0 ..< panelEnvironment.contentTopPanels.count {
                    let panel = panelEnvironment.contentTopPanels[index]
                    let indexOffset = index - centralIndex
                    
                    let panelFrame = CGRect(origin: CGPoint(x: CGFloat(indexOffset) * availableSize.width, y: 0.0), size: CGSize(width: availableSize.width, height: intrinsicHeight))
                    
                    let isInBounds = visibleBounds.intersects(panelFrame)
                    let isPartOfTransition: Bool
                    if !transitionOffsetFraction.isZero && self.panelViews[panel.id] != nil {
                        isPartOfTransition = true
                    } else {
                        isPartOfTransition = false
                    }
                     
                    if isInBounds || isPartOfTransition {
                        validPanelIds.insert(panel.id)
                        
                        var panelTransition = transition
                        let panelView: ComponentHostView<Empty>
                        if let current = self.panelViews[panel.id] {
                            panelView = current
                        } else {
                            panelTransition = .immediate
                            panelView = ComponentHostView<Empty>()
                            self.panelViews[panel.id] = panelView
                            self.addSubview(panelView)
                        }
                        
                        let _ = panelView.update(
                            transition: panelTransition,
                            component: panel.component,
                            environment: {},
                            containerSize: panelFrame.size
                        )
                        if isInBounds {
                            transition.animatePosition(view: panelView, from: CGPoint(x: transitionOffsetFraction * availableSize.width, y: 0.0), to: CGPoint(), additive: true, completion: nil)
                        }
                        panelTransition.setFrame(view: panelView, frame: panelFrame, completion: { [weak self] completed in
                            if isPartOfTransition && completed {
                                self?.state?.updated(transition: .immediate)
                            }
                        })
                    }
                }
            }
            var removedPanelIds: [AnyHashable] = []
            for (id, panelView) in self.panelViews {
                if !validPanelIds.contains(id) {
                    removedPanelIds.append(id)
                    panelView.removeFromSuperview()
                }
            }
            for id in removedPanelIds {
                self.panelViews.removeValue(forKey: id)
            }
            
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
