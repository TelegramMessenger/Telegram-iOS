import Foundation
import UIKit
import AsyncDisplayKit
import UIKitRuntimeUtils

struct KeyboardSurface {
    let host: UIView
}

public extension UIResponder {
    private struct Static {
        static weak var responder: UIResponder?
    }

    static func currentFirst() -> UIResponder? {
        Static.responder = nil
        UIApplication.shared.sendAction(#selector(UIResponder._trap), to: nil, from: nil, for: nil)
        return Static.responder
    }

    @objc private func _trap() {
        Static.responder = self
    }
}

private func getFirstResponder(_ view: UIView) -> UIView? {
    if view.isFirstResponder {
        return view
    } else {
        for subview in view.subviews {
            if let result = getFirstResponder(subview) {
                return result
            }
        }
        return nil
    }
}

class KeyboardManager {
    private let host: StatusBarHost
    
    private weak var previousFirstResponderView: UIView?
    private var interactiveInputOffset: CGFloat = 0.0
    
    var surfaces: [KeyboardSurface] = [] {
        didSet {
            self.updateSurfaces(oldValue)
        }
    }
    
    init(host: StatusBarHost) {
        self.host = host
    }
    
    func getCurrentKeyboardHeight() -> CGFloat {
        guard let keyboardView = self.host.keyboardView else {
            return 0.0
        }
        if !isViewVisibleInHierarchy(keyboardView) {
            return 0.0
        }
        return keyboardView.bounds.height
    }
    
    func updateInteractiveInputOffset(_ offset: CGFloat, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        guard let keyboardView = self.host.keyboardView else {
            return
        }
        
        self.interactiveInputOffset = offset
        
        let previousBounds = keyboardView.bounds
        let updatedBounds = CGRect(origin: CGPoint(x: 0.0, y: -offset), size: previousBounds.size)
        keyboardView.layer.bounds = updatedBounds
        if transition.isAnimated {
            transition.animateOffsetAdditive(layer: keyboardView.layer, offset: previousBounds.minY - updatedBounds.minY, completion: completion)
        } else {
            completion()
        }
        
        //transition.updateSublayerTransformOffset(layer: keyboardView.layer, offset: CGPoint(x: 0.0, y: offset))
    }
    
    private func updateSurfaces(_ previousSurfaces: [KeyboardSurface]) {
        guard let keyboardWindow = self.host.keyboardWindow else {
            return
        }
        
        var firstResponderView: UIView?
        var firstResponderDisableAutomaticKeyboardHandling: UIResponderDisableAutomaticKeyboardHandling = []
        for surface in self.surfaces {
            if let view = getFirstResponder(surface.host) {
                firstResponderView = surface.host
                firstResponderDisableAutomaticKeyboardHandling = view.disableAutomaticKeyboardHandling
                break
            }
        }
        
        if let firstResponderView = firstResponderView {
            let containerOrigin = firstResponderView.convert(CGPoint(), to: nil)
            var filteredTranslation = containerOrigin.x
            if firstResponderDisableAutomaticKeyboardHandling.contains(.forward) {
                filteredTranslation = max(0.0, filteredTranslation)
            }
            if firstResponderDisableAutomaticKeyboardHandling.contains(.backward) {
                filteredTranslation = min(0.0, filteredTranslation)
            }
            let horizontalTranslation = CATransform3DMakeTranslation(filteredTranslation, 0.0, 0.0)
            let currentTransform = keyboardWindow.layer.sublayerTransform
            if !CATransform3DEqualToTransform(horizontalTranslation, currentTransform) {
                //print("set to \(CGPoint(x: containerOrigin.x, y: self.interactiveInputOffset))")
                keyboardWindow.layer.sublayerTransform = horizontalTranslation
            }
        } else {
            keyboardWindow.layer.sublayerTransform = CATransform3DIdentity
            if let previousFirstResponderView = previousFirstResponderView {
                if previousFirstResponderView.window == nil {
                    keyboardWindow.isHidden = true
                    keyboardWindow.layer.cancelAnimationsRecursive(key: "position")
                    keyboardWindow.layer.cancelAnimationsRecursive(key: "bounds")
                    keyboardWindow.isHidden = false
                }
            }
        }
        
        self.previousFirstResponderView = firstResponderView
    }
}

private func endAnimations(view: UIView) {
    view.layer.removeAllAnimations()
    for subview in view.subviews {
        endAnimations(view: subview)
    }
}

public func viewTreeContainsFirstResponder(view: UIView) -> Bool {
    if view.isFirstResponder {
        return true
    } else {
        for subview in view.subviews {
            if viewTreeContainsFirstResponder(view: subview) {
                return true
            }
        }
        return false
    }
}

public final class KeyboardViewManager {
    private let host: StatusBarHost
    
    init(host: StatusBarHost) {
        self.host = host
    }
    
    public func dismissEditingWithoutAnimation(view: UIView) {
        if viewTreeContainsFirstResponder(view: view) {
            view.endEditing(true)
            if let keyboardWindow = self.host.keyboardWindow {
                for view in keyboardWindow.subviews {
                    endAnimations(view: view)
                }
            }
        }
    }
    
    public func update(leftEdge: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let keyboardWindow = self.host.keyboardWindow else {
            return
        }
        applyNavigationKeyboardLeftEdge(layer: keyboardWindow.layer, leftEdge: leftEdge, transition: transition)
    }

    /// The keyboard follows a transition's screen on the render server: `leftEdges` at `timing`'s samples.
    public func animate(leftEdges: [CGFloat], timing: NavigationKeyframeTiming) {
        guard let keyboardWindow = self.host.keyboardWindow else {
            return
        }
        applyNavigationKeyboardLeftEdges(layer: keyboardWindow.layer, leftEdges: leftEdges, timing: timing)
    }

}

/// The key of a navigation transition's keyboard keyframes on the keyboard window's layer.
let navigationKeyboardTransitionKey = "navigationTransition.sublayerTransform"

/// Puts the keyboard's left edge at `leftEdge`; a new edge supersedes a transition's keyboard keyframes (a forced ending
/// lays the screens out at their end, and the keyboard goes with them).
func applyNavigationKeyboardLeftEdge(layer: CALayer, leftEdge: CGFloat, transition: ContainedViewLayoutTransition) {
    layer.removeAnimation(forKey: navigationKeyboardTransitionKey)
    let current = layer.sublayerTransform
    transition.updateSublayerTransformOffset(layer: layer, offset: CGPoint(x: leftEdge, y: current.m42), completion: { _ in
    })
}

/// The keyboard's left edge along `leftEdges` at `timing`'s samples, on the render server; the model is the last edge.
func applyNavigationKeyboardLeftEdges(layer: CALayer, leftEdges: [CGFloat], timing: NavigationKeyframeTiming) {
    guard let last = leftEdges.last else {
        return
    }
    let current = layer.sublayerTransform
    func transform(_ edge: CGFloat) -> CATransform3D {
        var result = current
        result.m41 = edge
        return result
    }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.sublayerTransform = transform(last)
    CATransaction.commit()
    addNavigationKeyframes(to: layer, key: navigationKeyboardTransitionKey, keyPath: "sublayerTransform", values: leftEdges.map { NSValue(caTransform3D: transform($0)) }, timing: timing)
}
