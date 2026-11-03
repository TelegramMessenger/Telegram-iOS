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
    private let centerAlignment: Bool
    private let appear: ComponentTransition.Appear

    public init(_ items: [AnyComponentWithIdentity<ChildEnvironment>], direction: Direction = .vertical, centerAlignment: Bool = false, appear: ComponentTransition.Appear = .default()) {
        self.items = items
        self.direction = direction
        self.centerAlignment = centerAlignment
        self.appear = appear
    }

    public static func ==(lhs: List<ChildEnvironment>, rhs: List<ChildEnvironment>) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        if lhs.direction != rhs.direction {
            return false
        }
        if lhs.centerAlignment != rhs.centerAlignment {
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
            
            let maxWidth: CGFloat = updatedChildren.reduce(CGFloat(0.0)) { partialResult, child in
                return max(partialResult, child.size.width)
            }

            var nextOrigin: CGFloat = 0.0
            for child in updatedChildren {
                let position: CGPoint
                switch context.component.direction {
                    case .horizontal:
                        position = CGPoint(x: nextOrigin + child.size.width / 2.0, y: child.size.height / 2.0)
                        nextOrigin += child.size.width
                    case .vertical:
                        let originX: CGFloat
                        if context.component.centerAlignment {
                            originX = maxWidth / 2.0
                        } else {
                            originX = child.size.width / 2.0
                        }
                        position = CGPoint(x: originX, y: nextOrigin + child.size.height / 2.0)
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
                case .vertical:
                    let width: CGFloat
                    if context.component.centerAlignment {
                        width = maxWidth
                    } else {
                        width = context.availableSize.width
                    }
                    return CGSize(width: width, height: min(context.availableSize.height, nextOrigin))
            }
        }
    }
}
