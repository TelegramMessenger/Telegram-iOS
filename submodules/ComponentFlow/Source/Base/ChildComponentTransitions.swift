import Foundation
import UIKit

public extension ComponentTransition.Appear {
    static func `default`(scale: Bool = false, alpha: Bool = false) -> ComponentTransition.Appear {
        return ComponentTransition.Appear { component, view, transition in
            if scale {
                transition.animateScale(view: view, from: 0.01, to: 1.0)
            }
            if alpha {
                transition.animateAlpha(view: view, from: 0.0, to: 1.0)
            }
        }
    }

    static func scaleIn() -> ComponentTransition.Appear {
        return ComponentTransition.Appear { component, view, transition in
            transition.animateScale(view: view, from: 0.01, to: 1.0)
        }
    }
}

public extension ComponentTransition.AppearWithGuide {
    static func `default`(scale: Bool = false, alpha: Bool = false) -> ComponentTransition.AppearWithGuide {
        return ComponentTransition.AppearWithGuide { component, view, guide, transition in
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

public extension ComponentTransition.Disappear {
    static func `default`(scale: Bool = false, alpha: Bool = true) -> ComponentTransition.Disappear {
        return ComponentTransition.Disappear { view, transition, completion in
            if scale {
                transition.setScale(view: view, scale: 0.01, completion: { _ in
                    if !alpha {
                        completion()
                    }
                })
            }
            if alpha {
                transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                    completion()
                })
            }
            if !alpha && !scale {
                completion()
            }
        }
    }
}

public extension ComponentTransition.DisappearWithGuide {
    static func `default`(alpha: Bool = true) -> ComponentTransition.DisappearWithGuide {
        return ComponentTransition.DisappearWithGuide { stage, view, guide, transition, completion in
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

public extension ComponentTransition.Update {
    static let `default` = ComponentTransition.Update { component, view, transition in
        let position = component._position ?? CGPoint()
        let size = component.size
        view.layer.anchorPoint = component._anchorPoint ?? CGPoint(x: 0.5, y: 0.5)
        if let scale = component._scale {
            transition.setBounds(view: view, bounds: CGRect(origin: CGPoint(), size: size))
            transition.setPosition(view: view, position: position)
            transition.setScale(view: view, scale: scale)
        } else {
            if view is UIScrollView {
                let frame = component.size.centered(around: component._position ?? CGPoint())
                if view.frame != frame {
                    transition.setFrame(view: view, frame: frame)
                }
            } else {
                if component._anchorPoint != nil {
                    view.bounds = CGRect(origin: CGPoint(), size: size)
                } else {
                    transition.setBounds(view: view, bounds: CGRect(origin: CGPoint(), size: size))
                }
                transition.setPosition(view: view, position: position)
            }
        }
        let opacity = component._opacity ?? 1.0
        if view.alpha != opacity {
            transition.setAlpha(view: view, alpha: opacity)
        }
    }
}
