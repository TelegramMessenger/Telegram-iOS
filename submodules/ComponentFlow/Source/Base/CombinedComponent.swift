import Foundation
import UIKit

private func updateChildAnyComponent<EnvironmentType>(
    id: _AnyChildComponent.Id,
    component: AnyComponent<EnvironmentType>,
    view: UIView,
    availableSize: CGSize,
    transition: Transition
) -> _UpdatedChildComponent {
    let parentContext = _AnyCombinedComponentContext.current

    if !parentContext.updateContext.updatedViews.insert(id).inserted {
        preconditionFailure("Child component can only be processed once")
    }

    let context = view.context(component: component)
    var isEnvironmentUpdated = false
    var isStateUpdated = false
    var isComponentUpdated = false
    var availableSizeUpdated = false

    if context.environment.calculateIsUpdated() {
        context.environment._isUpdated = false
        isEnvironmentUpdated = true
    }

    if context.erasedState.isUpdated {
        context.erasedState.isUpdated = false
        isStateUpdated = true
    }

    if context.erasedComponent != component {
        isComponentUpdated = true
    }
    context.erasedComponent = component

    if context.layoutResult.availableSize != availableSize {
        context.layoutResult.availableSize = availableSize
        availableSizeUpdated = true
    }

    let isUpdated = isEnvironmentUpdated || isStateUpdated || isComponentUpdated || availableSizeUpdated

    if !isUpdated, let size = context.layoutResult.size {
        return _UpdatedChildComponent(
            id: id,
            component: component,
            view: view,
            context: context,
            size: size
        )
    } else {
        let size = component._update(
            view: view,
            availableSize: availableSize,
            environment: context.environment,
            transition: transition
        )
        context.layoutResult.size = size

        return _UpdatedChildComponent(
            id: id,
            component: component,
            view: view,
            context: context,
            size: size
        )
    }
}

public class _AnyChildComponent {
    fileprivate enum Id: Hashable {
        case direct(Int)
        case mapped(Int, AnyHashable)
    }

    fileprivate var directId: Int {
        return Int(bitPattern: Unmanaged.passUnretained(self).toOpaque())
    }
}

public final class _ConcreteChildComponent<ComponentType: Component>: _AnyChildComponent {
    fileprivate var id: Id {
        return .direct(self.directId)
    }

    public func update(component: ComponentType, @EnvironmentBuilder environment: () -> Environment<ComponentType.EnvironmentType>, availableSize: CGSize, transition: Transition) -> _UpdatedChildComponent {
        let parentContext = _AnyCombinedComponentContext.current
        if !parentContext.updateContext.configuredViews.insert(self.id).inserted {
            preconditionFailure("Child component can only be configured once")
        }

        var transition = transition

        let view: ComponentType.View
        if let current = parentContext.childViews[self.id] {
            // TODO: Check if the type is the same
            view = current.view as! ComponentType.View
        } else {
            view = component.makeView()
            transition = .immediate
        }

        let context = view.context(component: component)
        EnvironmentBuilder._environment = context.erasedEnvironment
        let _ = environment()
        EnvironmentBuilder._environment = nil

        return updateChildAnyComponent(
            id: self.id,
            component: AnyComponent(component),
            view: view,
            availableSize: availableSize,
            transition: transition
        )
    }
}

public extension _ConcreteChildComponent where ComponentType.EnvironmentType == Empty {
    func update(component: ComponentType, availableSize: CGSize, transition: Transition) -> _UpdatedChildComponent {
        return self.update(component: component, environment: {}, availableSize: availableSize, transition: transition)
    }
}

public final class _UpdatedChildComponentGuide {
    fileprivate let instance: _ChildComponentGuide

    fileprivate init(instance: _ChildComponentGuide) {
        self.instance = instance
    }
}

public final class _ChildComponentGuide {
    fileprivate var directId: Int {
        return Int(bitPattern: Unmanaged.passUnretained(self).toOpaque())
    }

    fileprivate var id: _AnyChildComponent.Id {
        return .direct(self.directId)
    }

    public func update(position: CGPoint, transition: Transition) -> _UpdatedChildComponentGuide {
        let parentContext = _AnyCombinedComponentContext.current

        let previousPosition = parentContext.guides[self.id]

        if parentContext.updateContext.configuredGuides.updateValue(_AnyCombinedComponentContext.UpdateContext.ConfiguredGuide(previousPosition: previousPosition ?? position, position: position), forKey: self.id) != nil {
            preconditionFailure("Child guide can only be configured once")
        }

        for disappearingView in parentContext.disappearingChildViews {
            if disappearingView.guideId == self.id {
                disappearingView.transitionWithGuide?(
                    stage: .update,
                    view: disappearingView.view,
                    guide: position,
                    transition: transition,
                    completion: disappearingView.completion
                )
            }
        }

        return _UpdatedChildComponentGuide(instance: self)
    }
}

public final class _UpdatedChildComponent {
    fileprivate let id: _AnyChildComponent.Id
    fileprivate let component: _TypeErasedComponent
    fileprivate let view: UIView
    fileprivate let context: _TypeErasedComponentContext

    public let size: CGSize

    var _removed: Bool = false
    var _position: CGPoint?
    var _scale: CGFloat?
    var _opacity: CGFloat?
    var _cornerRadius: CGFloat?
    var _clipsToBounds: Bool?

    fileprivate var transitionAppear: Transition.Appear?
    fileprivate var transitionAppearWithGuide: (Transition.AppearWithGuide, _AnyChildComponent.Id)?
    fileprivate var transitionDisappear: Transition.Disappear?
    fileprivate var transitionDisappearWithGuide: (Transition.DisappearWithGuide, _AnyChildComponent.Id)?
    fileprivate var transitionUpdate: Transition.Update?
    fileprivate var gestures: [Gesture] = []

    fileprivate init(
        id: _AnyChildComponent.Id,
        component: _TypeErasedComponent,
        view: UIView,
        context: _TypeErasedComponentContext,
        size: CGSize
    ) {
        self.id = id
        self.component = component
        self.view = view
        self.context = context
        self.size = size
    }

    @discardableResult public func appear(_ transition: Transition.Appear) -> _UpdatedChildComponent {
        self.transitionAppear = transition
        self.transitionAppearWithGuide = nil
        return self
    }

    @discardableResult public func appear(_ transition: Transition.AppearWithGuide, guide: _UpdatedChildComponentGuide) -> _UpdatedChildComponent {
        self.transitionAppear = nil
        self.transitionAppearWithGuide = (transition, guide.instance.id)
        return self
    }

    @discardableResult public func disappear(_ transition: Transition.Disappear) -> _UpdatedChildComponent {
        self.transitionDisappear = transition
        self.transitionDisappearWithGuide = nil
        return self
    }

    @discardableResult public func disappear(_ transition: Transition.DisappearWithGuide, guide: _UpdatedChildComponentGuide) -> _UpdatedChildComponent {
        self.transitionDisappear = nil
        self.transitionDisappearWithGuide = (transition, guide.instance.id)
        return self
    }

    @discardableResult public func update(_ transition: Transition.Update) -> _UpdatedChildComponent {
        self.transitionUpdate = transition
        return self
    }

    @discardableResult public func removed(_ removed: Bool) -> _UpdatedChildComponent {
        self._removed = removed
        return self
    }

    @discardableResult public func position(_ position: CGPoint) -> _UpdatedChildComponent {
        self._position = position
        return self
    }

    @discardableResult public func scale(_ scale: CGFloat) -> _UpdatedChildComponent {
        self._scale = scale
        return self
    }
    
    @discardableResult public func opacity(_ opacity: CGFloat) -> _UpdatedChildComponent {
        self._opacity = opacity
        return self
    }

    @discardableResult public func cornerRadius(_ cornerRadius: CGFloat) -> _UpdatedChildComponent {
        self._cornerRadius = cornerRadius
        return self
    }

    @discardableResult public func clipsToBounds(_ clipsToBounds: Bool) -> _UpdatedChildComponent {
        self._clipsToBounds = clipsToBounds
        return self
    }

    @discardableResult public func gesture(_ gesture: Gesture) -> _UpdatedChildComponent {
        self.gestures.append(gesture)
        return self
    }
}

public final class _EnvironmentChildComponent<EnvironmentType>: _AnyChildComponent {
    fileprivate var id: Id {
        return .direct(self.directId)
    }

    func update(component: AnyComponent<EnvironmentType>, @EnvironmentBuilder environment: () -> Environment<EnvironmentType>, availableSize: CGSize, transition: Transition) -> _UpdatedChildComponent {
        let parentContext = _AnyCombinedComponentContext.current
        if !parentContext.updateContext.configuredViews.insert(self.id).inserted {
            preconditionFailure("Child component can only be configured once")
        }

        var transition = transition

        let view: UIView
        if let current = parentContext.childViews[self.id] {
            // Check if the type is the same
            view = current.view
        } else {
            view = component._makeView()
            transition = .immediate
        }

        EnvironmentBuilder._environment = view.context(component: component).erasedEnvironment
        let _ = environment()
        EnvironmentBuilder._environment = nil

        return updateChildAnyComponent(
            id: self.id,
            component: component,
            view: view,
            availableSize: availableSize,
            transition: transition
        )
    }
}

public extension _EnvironmentChildComponent where EnvironmentType == Empty {
    func update(component: AnyComponent<EnvironmentType>, availableSize: CGSize, transition: Transition) -> _UpdatedChildComponent {
        return self.update(component: component, environment: {}, availableSize: availableSize, transition: transition)
    }
}

public extension _EnvironmentChildComponent {
    func update<ComponentType: Component>(_ component: ComponentType, @EnvironmentBuilder environment: () -> Environment<EnvironmentType>, availableSize: CGSize, transition: Transition) -> _UpdatedChildComponent where ComponentType.EnvironmentType == EnvironmentType {
        return self.update(component: AnyComponent(component), environment: environment, availableSize: availableSize, transition: transition)
    }

    func update<ComponentType: Component>(_ component: ComponentType, @EnvironmentBuilder environment: () -> Environment<EnvironmentType>, availableSize: CGSize, transition: Transition) -> _UpdatedChildComponent where ComponentType.EnvironmentType == EnvironmentType, EnvironmentType == Empty {
        return self.update(component: AnyComponent(component), environment: {}, availableSize: availableSize, transition: transition)
    }
}

public final class _EnvironmentChildComponentFromMap<EnvironmentType>: _AnyChildComponent {
    private let id: Id

    fileprivate init(id: Id) {
        self.id = id
    }

    public func update(component: AnyComponent<EnvironmentType>, @EnvironmentBuilder environment: () -> Environment<EnvironmentType>, availableSize: CGSize, transition: Transition) -> _UpdatedChildComponent {
        let parentContext = _AnyCombinedComponentContext.current
        if !parentContext.updateContext.configuredViews.insert(self.id).inserted {
            preconditionFailure("Child component can only be configured once")
        }

        var transition = transition

        let view: UIView
        if let current = parentContext.childViews[self.id] {
            // Check if the type is the same
            view = current.view
        } else {
            view = component._makeView()
            transition = .immediate
        }

        EnvironmentBuilder._environment = view.context(component: component).erasedEnvironment
        let _ = environment()
        EnvironmentBuilder._environment = nil

        return updateChildAnyComponent(
            id: self.id,
            component: component,
            view: view,
            availableSize: availableSize,
            transition: transition
        )
    }
}

public extension _EnvironmentChildComponentFromMap where EnvironmentType == Empty {
    func update(component: AnyComponent<EnvironmentType>, availableSize: CGSize, transition: Transition) -> _UpdatedChildComponent {
        return self.update(component: component, environment: {}, availableSize: availableSize, transition: transition)
    }
}

public final class _EnvironmentChildComponentMap<EnvironmentType, Key: Hashable> {
    private var directId: Int {
        return Int(bitPattern: Unmanaged.passUnretained(self).toOpaque())
    }

    public subscript(_ key: Key) -> _EnvironmentChildComponentFromMap<EnvironmentType> {
        get {
            return _EnvironmentChildComponentFromMap<EnvironmentType>(id: .mapped(self.directId, key))
        }
    }
}

public final class CombinedComponentContext<ComponentType: Component> {
    fileprivate let escapeGuard = EscapeGuard()

    private let context: ComponentContext<ComponentType>
    public let view: UIView

    public let component: ComponentType
    public let availableSize: CGSize
    public let transition: Transition
    private let addImpl: (_ updatedComponent: _UpdatedChildComponent) -> Void

    public var environment: Environment<ComponentType.EnvironmentType> {
        return self.context.environment
    }
    public var state: ComponentType.State {
        return self.context.state
    }

    fileprivate init(
        context: ComponentContext<ComponentType>,
        view: UIView,
        component: ComponentType,
        availableSize: CGSize,
        transition: Transition,
        add: @escaping (_ updatedComponent: _UpdatedChildComponent) -> Void
    ) {
        self.context = context
        self.view = view
        self.component = component
        self.availableSize = availableSize
        self.transition = transition
        self.addImpl = add
    }

    public func add(_ updatedComponent: _UpdatedChildComponent) {
        self.addImpl(updatedComponent)
    }
}

public protocol CombinedComponent: Component {
    typealias Body = (CombinedComponentContext<Self>) -> CGSize

    static var body: Body { get }
}

private class _AnyCombinedComponentContext {
    class UpdateContext {
        struct ConfiguredGuide {
            var previousPosition: CGPoint
            var position: CGPoint
        }

        var configuredViews: Set<_AnyChildComponent.Id> = Set()
        var updatedViews: Set<_AnyChildComponent.Id> = Set()
        var configuredGuides: [_AnyChildComponent.Id: ConfiguredGuide] = [:]
    }

    private static var _current: _AnyCombinedComponentContext?
    static var current: _AnyCombinedComponentContext {
        return self._current!
    }

    static func push(_ context: _AnyCombinedComponentContext) -> _AnyCombinedComponentContext? {
        let previous = self._current

        precondition(context._updateContext == nil)
        context._updateContext = UpdateContext()
        self._current = context

        return previous
    }

    static func pop(_ context: _AnyCombinedComponentContext, stack: _AnyCombinedComponentContext?) {
        precondition(context._updateContext != nil)
        context._updateContext = nil

        self._current = stack
    }

    class ChildView {
        let view: UIView
        var index: Int
        var transition: Transition.Disappear?
        var transitionWithGuide: (Transition.DisappearWithGuide, _AnyChildComponent.Id)?

        var gestures: [UInt: UIGestureRecognizer] = [:]

        init(view: UIView, index: Int) {
            self.view = view
            self.index = index
        }

        func updateGestures(_ gestures: [Gesture]) {
            var validIds: [UInt] = []
            for gesture in gestures {
                validIds.append(gesture.id.id)
                if let current = self.gestures[gesture.id.id] {
                    gesture.update(gesture: current)
                } else {
                    let gestureInstance = gesture.create()
                    self.gestures[gesture.id.id] = gestureInstance
                    self.view.isUserInteractionEnabled = true
                    self.view.addGestureRecognizer(gestureInstance)
                }
            }
            var removeIds: [UInt] = []
            for id in self.gestures.keys {
                if !validIds.contains(id) {
                    removeIds.append(id)
                }
            }
            for id in removeIds {
                if let gestureInstance = self.gestures.removeValue(forKey: id) {
                    self.view.removeGestureRecognizer(gestureInstance)
                }
            }
        }
    }

    class DisappearingChildView {
        let view: UIView
        let guideId: _AnyChildComponent.Id?
        let transition: Transition.Disappear?
        let transitionWithGuide: Transition.DisappearWithGuide?
        let completion: () -> Void

        init(
            view: UIView,
            guideId: _AnyChildComponent.Id?,
            transition: Transition.Disappear?,
            transitionWithGuide: Transition.DisappearWithGuide?,
            completion: @escaping () -> Void
        ) {
            self.view = view
            self.guideId = guideId
            self.transition = transition
            self.transitionWithGuide = transitionWithGuide
            self.completion = completion
        }
    }

    var childViews: [_AnyChildComponent.Id: ChildView] = [:]
    var childViewIndices: [_AnyChildComponent.Id] = []
    var guides: [_AnyChildComponent.Id: CGPoint] = [:]
    var disappearingChildViews: [DisappearingChildView] = []

    private var _updateContext: UpdateContext?
    var updateContext: UpdateContext {
        return self._updateContext!
    }
}

private final class _CombinedComponentContext<ComponentType: CombinedComponent>: _AnyCombinedComponentContext {
    var body: ComponentType.Body?
}

private var UIView_CombinedComponentContextKey: Int?

private extension UIView {
    func getCombinedComponentContext<ComponentType: CombinedComponent>(_ type: ComponentType.Type) -> _CombinedComponentContext<ComponentType> {
        if let context = objc_getAssociatedObject(self, &UIView_CombinedComponentContextKey) as? _CombinedComponentContext<ComponentType> {
            return context
        } else {
            let context = _CombinedComponentContext<ComponentType>()
            objc_setAssociatedObject(self, &UIView_CombinedComponentContextKey, context, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return context
        }
    }
}

public extension Transition {
    final class Appear {
        private let f: (_UpdatedChildComponent, UIView, Transition) -> Void

        public init(_ f: @escaping (_UpdatedChildComponent, UIView, Transition) -> Void) {
            self.f = f
        }

        public func callAsFunction(component: _UpdatedChildComponent, view: UIView, transition: Transition) {
            self.f(component, view, transition)
        }
    }

    final class AppearWithGuide {
        private let f: (_UpdatedChildComponent, UIView, CGPoint, Transition) -> Void

        public init(_ f: @escaping (_UpdatedChildComponent, UIView, CGPoint, Transition) -> Void) {
            self.f = f
        }

        public func callAsFunction(component: _UpdatedChildComponent, view: UIView, guide: CGPoint, transition: Transition) {
            self.f(component, view, guide, transition)
        }
    }

    final class Disappear {
        private let f: (UIView, Transition, @escaping () -> Void) -> Void

        public init(_ f: @escaping (UIView, Transition, @escaping () -> Void) -> Void) {
            self.f = f
        }

        public func callAsFunction(view: UIView, transition: Transition, completion: @escaping () -> Void) {
            self.f(view, transition, completion)
        }
    }

    final class DisappearWithGuide {
        public enum Stage {
            case begin
            case update
        }

        private let f: (Stage, UIView, CGPoint, Transition, @escaping () -> Void) -> Void

        public init(_ f: @escaping (Stage, UIView, CGPoint, Transition, @escaping () -> Void) -> Void
        ) {
            self.f = f
        }

        public func callAsFunction(stage: Stage, view: UIView, guide: CGPoint, transition: Transition, completion: @escaping () -> Void) {
            self.f(stage, view, guide, transition, completion)
        }
    }

    final class Update {
        private let f: (_UpdatedChildComponent, UIView, Transition) -> Void

        public init(_ f: @escaping (_UpdatedChildComponent, UIView, Transition) -> Void) {
            self.f = f
        }

        public func callAsFunction(component: _UpdatedChildComponent, view: UIView, transition: Transition) {
            self.f(component, view, transition)
        }
    }
}

public extension CombinedComponent {
    func makeView() -> UIView {
        return UIView()
    }

    func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        let context = view.getCombinedComponentContext(Self.self)
        
        let storedBody: Body
        if let current = context.body {
            storedBody = current
        } else {
            storedBody = Self.body
            context.body = storedBody
        }

        let viewContext = view.context(component: self)

        var nextChildIndex = 0
        var addedChildIds = Set<_AnyChildComponent.Id>()

        let contextStack = _AnyCombinedComponentContext.push(context)

        let escapeStatus: EscapeGuard.Status
        let size: CGSize
        do {
            let bodyContext = CombinedComponentContext<Self>(
                context: viewContext,
                view: view,
                component: self,
                availableSize: availableSize,
                transition: transition,
                add: { updatedChild in
                    if !addedChildIds.insert(updatedChild.id).inserted {
                        preconditionFailure("Child component can only be added once")
                    }

                    let index = nextChildIndex
                    nextChildIndex += 1

                    if let previousView = context.childViews[updatedChild.id] {
                        precondition(updatedChild.view === previousView.view)

                        if index != previousView.index {
                            assert(index < previousView.index)
                            for i in index ..< previousView.index {
                                if let moveView = context.childViews[context.childViewIndices[i]] {
                                    moveView.index += 1
                                }
                            }
                            context.childViewIndices.remove(at: previousView.index)
                            context.childViewIndices.insert(updatedChild.id, at: index)
                            previousView.index = index
                            view.insertSubview(previousView.view, at: index)
                        }

                        previousView.updateGestures(updatedChild.gestures)
                        previousView.transition = updatedChild.transitionDisappear
                        previousView.transitionWithGuide = updatedChild.transitionDisappearWithGuide

                        (updatedChild.transitionUpdate ?? Transition.Update.default)(component: updatedChild, view: updatedChild.view, transition: transition)
                    } else {
                        for i in index ..< context.childViewIndices.count {
                            if let moveView = context.childViews[context.childViewIndices[i]] {
                                moveView.index += 1
                            }
                        }

                        context.childViewIndices.insert(updatedChild.id, at: index)
                        let childView = _AnyCombinedComponentContext.ChildView(view: updatedChild.view, index: index)
                        context.childViews[updatedChild.id] = childView

                        childView.updateGestures(updatedChild.gestures)
                        childView.transition = updatedChild.transitionDisappear
                        childView.transitionWithGuide = updatedChild.transitionDisappearWithGuide

                        view.insertSubview(updatedChild.view, at: index)

                        if let scale = updatedChild._scale {
                            updatedChild.view.bounds = CGRect(origin: CGPoint(), size: updatedChild.size)
                            updatedChild.view.center = updatedChild._position ?? CGPoint()
                            updatedChild.view.transform = CGAffineTransform(scaleX: scale, y: scale)
                        } else {
                            updatedChild.view.frame = updatedChild.size.centered(around: updatedChild._position ?? CGPoint())
                        }
                        updatedChild.view.alpha = updatedChild._opacity ?? 1.0
                        updatedChild.view.clipsToBounds = updatedChild._clipsToBounds ?? false
                        updatedChild.view.layer.cornerRadius = updatedChild._cornerRadius ?? 0.0
                        updatedChild.view.context(typeErasedComponent: updatedChild.component).erasedState._updated = { [weak viewContext] transition in
                            guard let viewContext = viewContext else {
                                return
                            }
                            viewContext.state.updated(transition: transition)
                        }

                        if let transitionAppearWithGuide = updatedChild.transitionAppearWithGuide {
                            guard let guide = context.updateContext.configuredGuides[transitionAppearWithGuide.1] else {
                                preconditionFailure("Guide should be configured before using")
                            }
                            transitionAppearWithGuide.0(
                                component: updatedChild,
                                view: updatedChild.view,
                                guide: guide.previousPosition,
                                transition: transition
                            )
                        } else if let transitionAppear = updatedChild.transitionAppear {
                            transitionAppear(
                                component: updatedChild,
                                view: updatedChild.view,
                                transition: transition
                            )
                        }
                    }
                }
            )

            escapeStatus = bodyContext.escapeGuard.status
            size = storedBody(bodyContext)
        }

        assert(escapeStatus.isDeallocated, "Body context should not be stored for later use")

        if nextChildIndex < context.childViewIndices.count {
            for i in nextChildIndex ..< context.childViewIndices.count {
                let id = context.childViewIndices[i]
                if let childView = context.childViews.removeValue(forKey: id) {
                    let view = childView.view
                    let completion: () -> Void = { [weak context, weak view] in
                        view?.removeFromSuperview()

                        if let context = context {
                            for i in 0 ..< context.disappearingChildViews.count {
                                if context.disappearingChildViews[i].view === view {
                                    context.disappearingChildViews.remove(at: i)
                                    break
                                }
                            }
                        }
                    }
                    if let transitionWithGuide = childView.transitionWithGuide {
                        guard let guide = context.updateContext.configuredGuides[transitionWithGuide.1] else {
                            preconditionFailure("Guide should be configured before using")
                        }
                        context.disappearingChildViews.append(_AnyCombinedComponentContext.DisappearingChildView(
                            view: view,
                            guideId: transitionWithGuide.1,
                            transition: nil,
                            transitionWithGuide: transitionWithGuide.0,
                            completion: completion
                        ))
                        view.isUserInteractionEnabled = false
                        transitionWithGuide.0(
                            stage: .begin,
                            view: view,
                            guide: guide.position,
                            transition: transition,
                            completion: completion
                        )
                    } else if let simpleTransition = childView.transition {
                        context.disappearingChildViews.append(_AnyCombinedComponentContext.DisappearingChildView(
                            view: view,
                            guideId: nil,
                            transition: simpleTransition,
                            transitionWithGuide: nil,
                            completion: completion
                        ))
                        view.isUserInteractionEnabled = false
                        simpleTransition(
                            view: view,
                            transition: transition,
                            completion: completion
                        )
                    } else {
                        childView.view.removeFromSuperview()
                    }
                }
            }
            context.childViewIndices.removeSubrange(nextChildIndex...)
        }

        if addedChildIds != context.updateContext.updatedViews {
            preconditionFailure("Updated and added child lists do not match")
        }

        context.guides.removeAll()
        for (id, guide) in context.updateContext.configuredGuides {
            context.guides[id] = guide.position
        }

        _AnyCombinedComponentContext.pop(context, stack: contextStack)

        return size
    }
}

public extension CombinedComponent {
    static func Child<Environment>(environment: Environment.Type) -> _EnvironmentChildComponent<Environment> {
        return _EnvironmentChildComponent<Environment>()
    }

    static func ChildMap<Environment, Key: Hashable>(environment: Environment.Type, keyedBy keyType: Key.Type) -> _EnvironmentChildComponentMap<Environment, Key> {
        return _EnvironmentChildComponentMap<Environment, Key>()
    }

    static func Child<ComponentType: Component>(_ type: ComponentType.Type) -> _ConcreteChildComponent<ComponentType> {
        return _ConcreteChildComponent<ComponentType>()
    }

    static func Guide() -> _ChildComponentGuide {
        return _ChildComponentGuide()
    }
    
    static func StoredActionSlot<Arguments>(_ argumentsType: Arguments.Type) -> ActionSlot<Arguments> {
        return ActionSlot<Arguments>()
    }
}
