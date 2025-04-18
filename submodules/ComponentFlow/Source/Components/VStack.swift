import Foundation
import UIKit

public enum VStackAlignment {
    case left
    case center
    case right
}

public final class VStack<ChildEnvironment: Equatable>: CombinedComponent {
    public typealias EnvironmentType = ChildEnvironment

    private let items: [AnyComponentWithIdentity<ChildEnvironment>]
    private let alignment: VStackAlignment
    private let spacing: CGFloat
    private let fillWidth: Bool

    public init(_ items: [AnyComponentWithIdentity<ChildEnvironment>], alignment: VStackAlignment = .center, spacing: CGFloat, fillWidth: Bool = false) {
        self.items = items
        self.alignment = alignment
        self.spacing = spacing
        self.fillWidth = fillWidth
    }

    public static func ==(lhs: VStack<ChildEnvironment>, rhs: VStack<ChildEnvironment>) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        if lhs.alignment != rhs.alignment {
            return false
        }
        if lhs.spacing != rhs.spacing {
            return false
        }
        if lhs.fillWidth != rhs.fillWidth {
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

            var size = CGSize(width: 0.0, height: 0.0)
            if context.component.fillWidth {
                size.width = context.availableSize.width
            }
            for child in updatedChildren {
                size.height += child.size.height
                size.width = max(size.width, child.size.width)
            }
            size.height += context.component.spacing * CGFloat(updatedChildren.count - 1)
            
            var nextY = 0.0
            for child in updatedChildren {
                let childFrame: CGRect
                switch context.component.alignment {
                case .left:
                    childFrame = CGRect(origin: CGPoint(x: 0.0, y: nextY), size: child.size)
                case .center:
                    childFrame = CGRect(origin: CGPoint(x: floor((size.width - child.size.width) * 0.5), y: nextY), size: child.size)
                case .right:
                    childFrame = CGRect(origin: CGPoint(x: size.width - child.size.width, y: nextY), size: child.size)
                }
                context.add(child
                    .position(childFrame.center)
                    .appear(.default(scale: true, alpha: true))
                    .disappear(.default(scale: true, alpha: true))
                )
                nextY += child.size.height
                nextY += context.component.spacing
            }

            return size
        }
    }
}
