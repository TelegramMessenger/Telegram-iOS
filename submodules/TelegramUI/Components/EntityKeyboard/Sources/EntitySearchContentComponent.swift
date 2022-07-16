import Foundation
import UIKit
import Display
import ComponentFlow
import PagerComponent
import TelegramPresentationData
import TelegramCore
import Postbox
import AnimationCache
import MultiAnimationRenderer
import AccountContext
import AsyncDisplayKit
import ComponentDisplayAdapters

public protocol EntitySearchContainerNode: ASDisplayNode {
    var onCancel: (() -> Void)? { get set }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, inputHeight: CGFloat, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition)
}

final class EntitySearchContentEnvironment: Equatable {
    let context: AccountContext
    let theme: PresentationTheme
    let deviceMetrics: DeviceMetrics
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        deviceMetrics: DeviceMetrics
    ) {
        self.context = context
        self.theme = theme
        self.deviceMetrics = deviceMetrics
    }
    
    static func ==(lhs: EntitySearchContentEnvironment, rhs: EntitySearchContentEnvironment) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.deviceMetrics != rhs.deviceMetrics {
            return false
        }
        
        return true
    }
}

final class EntitySearchContentComponent: Component {
    typealias EnvironmentType = EntitySearchContentEnvironment
    
    let makeContainerNode: () -> EntitySearchContainerNode?
    let dismissSearch: () -> Void
    
    init(
        makeContainerNode: @escaping () -> EntitySearchContainerNode?,
        dismissSearch: @escaping () -> Void
    ) {
        self.makeContainerNode = makeContainerNode
        self.dismissSearch = dismissSearch
    }
    
    static func ==(lhs: EntitySearchContentComponent, rhs: EntitySearchContentComponent) -> Bool {
        return true
    }
    
    final class View: UIView {
        private var containerNode: EntitySearchContainerNode?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: EntitySearchContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            let containerNode: EntitySearchContainerNode?
            if let current = self.containerNode {
                containerNode = current
            } else {
                containerNode = component.makeContainerNode()
                if let containerNode = containerNode {
                    self.containerNode = containerNode
                    self.addSubnode(containerNode)
                }
            }
            
            if let containerNode = containerNode {
            
            let environmentValue = environment[EntitySearchContentEnvironment.self].value
                transition.setFrame(view: containerNode.view, frame: CGRect(origin: CGPoint(), size: availableSize))
                containerNode.updateLayout(
                    size: availableSize,
                    leftInset: 0.0,
                    rightInset: 0.0,
                    bottomInset: 0.0,
                    inputHeight: 0.0,
                    deviceMetrics: environmentValue.deviceMetrics,
                    transition: transition.containedViewLayoutTransition
                )
                
                containerNode.onCancel = {
                    component.dismissSearch()
                }
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
