import Foundation
import UIKit
import Display
import ComponentFlow
import PagerComponent
import TelegramPresentationData
import TelegramCore
import Postbox

public final class EntityKeyboardTopContainerPanelEnvironment: Equatable {
    let visibilityFractionUpdated: ActionSlot<(CGFloat, Transition)>
    let isExpandedUpdated: (Bool, Transition) -> Void
    
    init(
        visibilityFractionUpdated: ActionSlot<(CGFloat, Transition)>,
        isExpandedUpdated: @escaping (Bool, Transition) -> Void
    ) {
        self.visibilityFractionUpdated = visibilityFractionUpdated
        self.isExpandedUpdated = isExpandedUpdated
    }
    
    public static func ==(lhs: EntityKeyboardTopContainerPanelEnvironment, rhs: EntityKeyboardTopContainerPanelEnvironment) -> Bool {
        if lhs.visibilityFractionUpdated !== rhs.visibilityFractionUpdated {
            return false
        }
        return true
    }
}

final class EntityKeyboardTopContainerPanelComponent: Component {
    typealias EnvironmentType = PagerComponentPanelEnvironment<EntityKeyboardTopContainerPanelEnvironment>
    
    let theme: PresentationTheme
    let overflowHeight: CGFloat
    let displayBackground: Bool
    
    init(
        theme: PresentationTheme,
        overflowHeight: CGFloat,
        displayBackground: Bool
    ) {
        self.theme = theme
        self.overflowHeight = overflowHeight
        self.displayBackground = displayBackground
    }
    
    static func ==(lhs: EntityKeyboardTopContainerPanelComponent, rhs: EntityKeyboardTopContainerPanelComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.overflowHeight != rhs.overflowHeight {
            return false
        }
        if lhs.displayBackground != rhs.displayBackground {
            return false
        }
        
        return true
    }
    
    private final class PanelView {
        let view = ComponentHostView<EntityKeyboardTopContainerPanelEnvironment>()
        let visibilityFractionUpdated = ActionSlot<(CGFloat, Transition)>()
        var isExpanded: Bool = false
    }
    
    final class View: UIView {
        private var backgroundView: BlurredBackgroundView?
        private var backgroundSeparatorView: UIView?
        
        private var panelViews: [AnyHashable: PanelView] = [:]
        
        private var component: EntityKeyboardTopContainerPanelComponent?
        private var panelEnvironment: PagerComponentPanelEnvironment<EntityKeyboardTopContainerPanelEnvironment>?
        private weak var state: EmptyComponentState?
        
        private var visibilityFraction: CGFloat = 1.0
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.disablesInteractiveKeyboardGestureRecognizer = true
            self.disablesInteractiveTransitionGestureRecognizer = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: EntityKeyboardTopContainerPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            let intrinsicHeight: CGFloat = 34.0
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
                    
                    let panelFrame = CGRect(origin: CGPoint(x: CGFloat(indexOffset) * availableSize.width, y: -component.overflowHeight), size: CGSize(width: availableSize.width, height: intrinsicHeight + component.overflowHeight))
                    
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
                        let panelView: PanelView
                        if let current = self.panelViews[panel.id] {
                            panelView = current
                        } else {
                            panelTransition = .immediate
                            panelView = PanelView()
                            self.panelViews[panel.id] = panelView
                            self.addSubview(panelView.view)
                        }
                        
                        let panelId = panel.id
                        let _ = panelView.view.update(
                            transition: panelTransition,
                            component: panel.component,
                            environment: {
                                EntityKeyboardTopContainerPanelEnvironment(
                                    visibilityFractionUpdated: panelView.visibilityFractionUpdated,
                                    isExpandedUpdated: { [weak self] isExpanded, transition in
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        strongSelf.panelIsExpandedUpdated(id: panelId, isExpanded: isExpanded, transition: transition)
                                    }
                                )
                            },
                            containerSize: panelFrame.size
                        )
                        if isInBounds {
                            transition.animatePosition(view: panelView.view, from: CGPoint(x: transitionOffsetFraction * availableSize.width, y: 0.0), to: CGPoint(), additive: true, completion: nil)
                        }
                        panelTransition.setFrame(view: panelView.view, frame: panelFrame, completion: { [weak self] completed in
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
                    panelView.view.removeFromSuperview()
                }
            }
            for id in removedPanelIds {
                self.panelViews.removeValue(forKey: id)
            }
            
            environment[PagerComponentPanelEnvironment.self].value.visibilityFractionUpdated.connect { [weak self] (fraction, transition) in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.updateVisibilityFraction(value: fraction, transition: transition)
            }
            
            if component.displayBackground {
                let backgroundView: BlurredBackgroundView
                if let current = self.backgroundView {
                    backgroundView = current
                } else {
                    backgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
                    self.insertSubview(backgroundView, at: 0)
                }
                
                let backgroundSeparatorView: UIView
                if let current = self.backgroundSeparatorView {
                    backgroundSeparatorView = current
                } else {
                    backgroundSeparatorView = UIView()
                    self.insertSubview(backgroundSeparatorView, aboveSubview: backgroundView)
                }
                
                backgroundView.updateColor(color: component.theme.chat.inputPanel.panelBackgroundColor.withMultipliedAlpha(1.0), transition: .immediate)
                backgroundView.update(size: CGSize(width: availableSize.width, height: height), transition: transition.containedViewLayoutTransition)
                transition.setFrame(view: backgroundView, frame: CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: height)))
                
                backgroundSeparatorView.backgroundColor = component.theme.chat.inputPanel.panelSeparatorColor
                transition.setFrame(view: backgroundSeparatorView, frame: CGRect(origin: CGPoint(x: 0.0, y: height), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            } else {
                if let backgroundView = self.backgroundView {
                    self.backgroundView = nil
                    backgroundView.removeFromSuperview()
                }
                if let backgroundSeparatorView = self.backgroundSeparatorView {
                    self.backgroundSeparatorView = nil
                    backgroundSeparatorView.removeFromSuperview()
                }
            }
            
            return CGSize(width: availableSize.width, height: height)
        }
        
        private func updateVisibilityFraction(value: CGFloat, transition: Transition) {
            if self.visibilityFraction == value {
                return
            }
            
            self.visibilityFraction = value
            for (_, panelView) in self.panelViews {
                panelView.visibilityFractionUpdated.invoke((value, transition))
                transition.setSublayerTransform(view: panelView.view, transform: CATransform3DMakeTranslation(0.0, -panelView.view.bounds.height / 2.0 * (1.0 - value), 0.0))
            }
        }
        
        private func panelIsExpandedUpdated(id: AnyHashable, isExpanded: Bool, transition: Transition) {
            guard let panelView = self.panelViews[id] else {
                return
            }
            if panelView.isExpanded == isExpanded {
                return
            }
            panelView.isExpanded = isExpanded
            
            var hasExpanded = false
            for (_, panel) in self.panelViews {
                if panel.isExpanded {
                    hasExpanded = true
                    break
                }
            }

            self.panelEnvironment?.isExpandedUpdated(hasExpanded, transition)
        }
        
        public func internalUpdatePanelsAreCollapsed() {
            for (_, panelView) in self.panelViews {
                panelView.isExpanded = false
            }
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if self.alpha.isZero {
                return nil
            }
            for view in self.subviews.reversed() {
                if let result = view.hitTest(self.convert(point, to: view), with: event), result.isUserInteractionEnabled {
                    return result
                }
            }
            
            let result = super.hitTest(point, with: event)
            if result != self {
                return result
            } else {
                return nil
            }
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
