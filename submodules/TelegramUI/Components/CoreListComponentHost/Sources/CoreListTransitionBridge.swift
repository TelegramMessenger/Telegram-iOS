import Foundation
import Display
import ComponentFlow
import CoreList

// CoreList cannot depend on ComponentFlow — its Bazel target has no `deps` and its demo builds
// standalone in Xcode — so it carries a case-for-case copy of the transition value model. This is
// where the two meet (moved here from `CoreListChatHistoryBackend.swift` so the chat backend and the
// News feed share one copy).
//
// The one asymmetry is interpretation, not data: CoreList treats a zero duration as immediate, while
// ComponentFlow animates it. That difference is preserved here rather than smoothed over — a
// zero-duration CoreList transition maps to `.immediate`, so a caller converting one and handing it
// to UIKit gets the behavior CoreList meant.
public extension ComponentTransition {
    init(_ transition: CoreListTransition) {
        switch transition.animation {
        case .none:
            self.init(animation: .none)
        case let .curve(duration, curve):
            guard !transition.isImmediate else {
                self.init(animation: .none)
                return
            }
            self.init(animation: .curve(duration: duration,
                                        curve: ComponentTransition.Animation.Curve(curve)))
        }
    }
}

public extension CoreListTransition {
    /// A layout transition as a pass transition, case for case, so a list moves on the very curve the layout
    /// around it animates on. The News feeds and the chat history's item transitions both map through it.
    init(_ transition: ContainedViewLayoutTransition) {
        switch transition {
        case .immediate:
            self = .immediate
        case let .animated(duration, curve):
            let listCurve: CoreListTransition.Animation.Curve
            switch curve {
            case .linear:
                listCurve = .linear
            case .easeInOut:
                listCurve = .easeInOut
            case .easeIn:
                listCurve = .easeIn
            case .spring:
                listCurve = .spring
            case let .customSpring(mass, stiffness, damping, initialVelocity):
                listCurve = .customSpring(mass: mass, stiffness: stiffness, damping: damping, initialVelocity: initialVelocity)
            case let .custom(x1, y1, x2, y2):
                listCurve = .custom(x1, y1, x2, y2)
            }
            self.init(animation: .curve(duration: duration, curve: listCurve))
        }
    }
}

private extension ComponentTransition.Animation.Curve {
    init(_ curve: CoreListTransition.Animation.Curve) {
        switch curve {
        case .easeInOut: self = .easeInOut
        case .easeIn: self = .easeIn
        case .spring: self = .spring
        case .linear: self = .linear
        case let .custom(a, b, c, d): self = .custom(a, b, c, d)
        case let .bounce(stiffness, damping): self = .bounce(stiffness: stiffness, damping: damping)
        case .uiKitSmoothDeceleration, .customSpring:
            // Lossy, and the only lossy arms here: ComponentFlow has no critically-damped-spring
            // case and no parameterised spring (its `.bounce` is a different spring API), and its
            // `.custom` is a cubic bezier, which is exactly what these curves are not. `.spring` is
            // the nearest family. This bridge only feeds item-internal
            // ContainedViewLayoutTransitions — the scroll itself is animated by CoreList from the
            // real CASpringAnimation, so the approximation never reaches the offset.
            self = .spring
        }
    }
}
