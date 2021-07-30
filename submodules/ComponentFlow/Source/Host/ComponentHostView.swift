import Foundation
import UIKit

public final class ComponentHostView<EnvironmentType>: UIView {
    private var componentView: UIView?
    private(set) var isUpdating: Bool = false
    
    public init() {
        super.init(frame: CGRect())
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(transition: Transition, component: AnyComponent<EnvironmentType>, @EnvironmentBuilder environment: () -> Environment<EnvironmentType>, containerSize: CGSize) -> CGSize {
        self._update(transition: transition, component: component, maybeEnvironment: environment, updateEnvironment: true, containerSize: containerSize)
    }

    private func _update(transition: Transition, component: AnyComponent<EnvironmentType>, maybeEnvironment: () -> Environment<EnvironmentType>, updateEnvironment: Bool, containerSize: CGSize) -> CGSize {
        precondition(!self.isUpdating)
        self.isUpdating = true

        precondition(containerSize.width.isFinite)
        precondition(containerSize.width < .greatestFiniteMagnitude)
        precondition(containerSize.height.isFinite)
        precondition(containerSize.height < .greatestFiniteMagnitude)
        
        let componentView: UIView
        if let current = self.componentView {
            componentView = current
        } else {
            componentView = component._makeView()
            self.componentView = componentView
            self.addSubview(componentView)
        }

        let context = componentView.context(component: component)

        let componentState: ComponentState = context.erasedState

        if updateEnvironment {
            EnvironmentBuilder._environment = context.erasedEnvironment
            let _ = maybeEnvironment()
            EnvironmentBuilder._environment = nil
        }

        componentState._updated = { [weak self] transition in
            guard let strongSelf = self else {
                return
            }
            let _ = strongSelf._update(transition: transition, component: component, maybeEnvironment: {
                preconditionFailure()
            } as () -> Environment<EnvironmentType>, updateEnvironment: false, containerSize: containerSize)
        }

        let updatedSize = component._update(view: componentView, availableSize: containerSize, transition: transition)
        transition.setFrame(view: componentView, frame: CGRect(origin: CGPoint(), size: updatedSize))

        self.isUpdating = false

        return updatedSize
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        return result
    }
}
