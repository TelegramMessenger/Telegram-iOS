import Foundation
import UIKit

public final class List<ChildEnvironment: Equatable>: CombinedComponent {
    public enum Direction {
        case horizontal
        case vertical
    }
    
    public typealias EnvironmentType = ChildEnvironment

    private let items: [AnyComponentWithIdentity<ChildEnvironment>]
    private let direction: Direction
    private let appear: Transition.Appear

    public init(_ items: [AnyComponentWithIdentity<ChildEnvironment>], direction: Direction = .vertical, appear: Transition.Appear = .default()) {
        self.items = items
        self.direction = direction
        self.appear = appear
    }

    public static func ==(lhs: List<ChildEnvironment>, rhs: List<ChildEnvironment>) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        if lhs.direction != rhs.direction {
            return false
        }
        return true
    }

    public static var body: Body {
        let children = ChildMap(environment: ChildEnvironment.self, keyedBy: AnyHashable.self)

        return { context in
            let updatedChildren = context.component.items.map { item in
                return children[item.id].update(
                    component: item.component, environment: {
                        context.environment[ChildEnvironment.self]
                    },
                    availableSize: context.availableSize,
                    transition: context.transition
                )
            }

            var nextOrigin: CGFloat = 0.0
            for child in updatedChildren {
                let position: CGPoint
                switch context.component.direction {
                    case .horizontal:
                        position = CGPoint(x: nextOrigin + child.size.width / 2.0, y: child.size.height / 2.0)
                        nextOrigin += child.size.width
                    case .vertical:
                        position = CGPoint(x: child.size.width / 2.0, y: nextOrigin + child.size.height / 2.0)
                        nextOrigin += child.size.height
                }
                context.add(child
                    .position(position)
                    .appear(context.component.appear)
                )
            }

            switch context.component.direction {
                case .horizontal:
                    return CGSize(width: min(context.availableSize.width, nextOrigin), height: context.availableSize.height)
                case.vertical:
                    return CGSize(width: context.availableSize.width, height: min(context.availableSize.height, nextOrigin))
            }
        }
    }
}
