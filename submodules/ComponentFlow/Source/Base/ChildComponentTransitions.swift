import Foundation
import UIKit

public extension Transition.Appear {
    static func `default`(scale: Bool = false, alpha: Bool = false) -> Transition.Appear {
        return Transition.Appear { component, view, transition in
            if scale {
                transition.animateScale(view: view, from: 0.01, to: 1.0)
            }
            if alpha {
                transition.animateAlpha(view: view, from: 0.0, to: 1.0)
            }
        }
    }

    static func scaleIn() -> Transition.Appear {
        return Transition.Appear { component, view, transition in
            transition.animateScale(view: view, from: 0.01, to: 1.0)
        }
    }
}

public extension Transition.AppearWithGuide {
    static func `default`(scale: Bool = false, alpha: Bool = false) -> Transition.AppearWithGuide {
        return Transition.AppearWithGuide { component, view, guide, transition in
            if scale {
                transition.animateScale(view: view, from: 0.01, to: 1.0)
            }
            if alpha {
                transition.animateAlpha(view: view, from: 0.0, to: 1.0)
            }
            transition.animatePosition(view: view, from: CGPoint(x: guide.x - view.center.x, y: guide.y - view.center.y), to: CGPoint(), additive: true)
        }
    }
}

public extension Transition.Disappear {
    static let `default` = Transition.Disappear { view, transition, completion in
        transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
            completion()
        })
    }
}

public extension Transition.DisappearWithGuide {
    static func `default`(alpha: Bool = true) -> Transition.DisappearWithGuide {
        return Transition.DisappearWithGuide { stage, view, guide, transition, completion in
            switch stage {
            case .begin:
                if alpha {
                    transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        completion()
                    })
                }
                transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: guide.x - view.bounds.width / 2.0, y: guide.y - view.bounds.height / 2.0), size: view.bounds.size), completion: { _ in
                    if !alpha {
                        completion()
                    }
                })
            case .update:
                transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: guide.x - view.bounds.width / 2.0, y: guide.y - view.bounds.height / 2.0), size: view.bounds.size))
            }
        }
    }
}

public extension Transition.Update {
    static let `default` = Transition.Update { component, view, transition in
        let frame = component.size.centered(around: component._position ?? CGPoint())
        if view.frame != frame {
            transition.setFrame(view: view, frame: frame)
        }
        let opacity = component._opacity ?? 1.0
        if view.alpha != opacity {
            transition.setAlpha(view: view, alpha: opacity)
        }
    }
}
