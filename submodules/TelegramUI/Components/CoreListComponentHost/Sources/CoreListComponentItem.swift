import Foundation
import UIKit
import ComponentFlow
import CoreList

/// A CoreList row whose content is one ComponentFlow component, laid out at the row's width.
public final class CoreListComponentItem: CoreListItem {
    public let identity: AnyHashable
    public let component: AnyComponent<Empty>

    public init(identity: AnyHashable, component: AnyComponent<Empty>) {
        self.identity = identity
        self.component = component
    }

    public func view() -> UIView & CoreListItemView {
        return CoreListComponentItemView(component: self.component)
    }

    public func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? CoreListComponentItem else {
            return false
        }
        return self.identity == other.identity && self.component == other.component
    }

    public func apply(to view: UIView & CoreListItemView, transition: CoreListTransition) {
        (view as? CoreListComponentItemView)?.setComponent(self.component)
    }
}

/// Hosts the component. CoreList owns this view's frame and calls `update(width:transition:)`; a state
/// update inside the component asks CoreList to remeasure the row through `onContentDidChange`.
public final class CoreListComponentItemView: UIView, CoreListItemView {
    private let hostedView = ComponentView<Empty>()
    private let hostState = EmptyComponentState()
    private var component: AnyComponent<Empty>

    public var onContentDidChange: ((Bool) -> Void)?

    public var componentView: UIView? {
        return self.hostedView.view
    }

    init(component: AnyComponent<Empty>) {
        self.component = component
        super.init(frame: CGRect())
        self.hostedView.parentState = self.hostState
        self.hostState._updated = { [weak self] transition, _ in
            self?.onContentDidChange?(!transition.animation.isImmediate)
        }
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    func setComponent(_ component: AnyComponent<Empty>) {
        self.component = component
    }

    public func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        let componentTransition = ComponentTransition(transition)
        let size = self.hostedView.update(
            transition: componentTransition,
            component: self.component,
            environment: {},
            containerSize: CGSize(width: width, height: 100000.0)
        )
        if let view = self.hostedView.view {
            if view.superview == nil {
                self.addSubview(view)
            }
            componentTransition.setFrame(view: view, frame: CGRect(origin: CGPoint(), size: size))
        }
        return size.height
    }
}
