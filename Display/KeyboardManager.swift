import Foundation
import AsyncDisplayKit

struct KeyboardSurface {
    let host: UIView
}

private func hasFirstResponder(_ view: UIView) -> Bool {
    if view.isFirstResponder {
        return true
    } else {
        for subview in view.subviews {
            if hasFirstResponder(subview) {
                return true
            }
        }
        return false
    }
}

private func findKeyboardBackdrop(_ view: UIView) -> UIView? {
    if NSStringFromClass(type(of: view)) == "UIKBInputBackdropView" {
        return view
    }
    for subview in view.subviews {
        if let result = findKeyboardBackdrop(subview) {
            return result
        }
    }
    return nil
}

class KeyboardManager {
    private let host: StatusBarHost
    
    private weak var previousPositionAnimationMirrorSource: CATracingLayer?
    private weak var previousFirstResponderView: UIView?
    
    var gestureRecognizer: MinimizeKeyboardGestureRecognizer? = nil
    
    var minimized: Bool = false
    var minimizedUpdated: (() -> Void)?
    
    var updatedMinimizedBackdrop = false
    
    var surfaces: [KeyboardSurface] = [] {
        didSet {
            self.updateSurfaces(oldValue)
        }
    }
    
    init(host: StatusBarHost) {
        self.host = host
    }
    
    private func updateSurfaces(_ previousSurfaces: [KeyboardSurface]) {
        guard let keyboardWindow = self.host.keyboardWindow else {
            return
        }
        
        if let keyboardView = self.host.keyboardView {
            if self.minimized {
                let normalizedHeight = floor(0.85 * keyboardView.frame.size.height)
                let factor = normalizedHeight / keyboardView.frame.size.height
                let scaleTransform = CATransform3DMakeScale(factor, factor, 1.0)
                let horizontalOffset = (keyboardView.frame.size.width - keyboardView.frame.size.width * factor) / 2.0
                let verticalOffset = (keyboardView.frame.size.height - keyboardView.frame.size.height * factor) / 2.0
                let translate = CATransform3DMakeTranslation(horizontalOffset, verticalOffset, 0.0)
                keyboardView.layer.sublayerTransform = CATransform3DConcat(scaleTransform, translate)
                
                self.updatedMinimizedBackdrop = false
                
                if let backdrop = findKeyboardBackdrop(keyboardView) {
                    let scale = CATransform3DMakeScale(1.0 / factor, 1.0, 0.0)
                    let translate = CATransform3DMakeTranslation(-horizontalOffset * (1.0 / factor), 0.0, 0.0)
                    backdrop.layer.sublayerTransform = CATransform3DConcat(scale, translate)
                }
            } else {
                keyboardView.layer.sublayerTransform = CATransform3DIdentity
                if !self.updatedMinimizedBackdrop {
                    if let backdrop = findKeyboardBackdrop(keyboardView) {
                        backdrop.layer.sublayerTransform = CATransform3DIdentity
                    }
                    
                    self.updatedMinimizedBackdrop = true
                }
            }
        }
        
        if let gestureRecognizer = self.gestureRecognizer {
            if keyboardWindow.gestureRecognizers == nil || !keyboardWindow.gestureRecognizers!.contains(gestureRecognizer) {
                keyboardWindow.addGestureRecognizer(gestureRecognizer)
            }
        } else {
            let gestureRecognizer = MinimizeKeyboardGestureRecognizer(target: self, action: #selector(self.minimizeGesture(_:)))
            self.gestureRecognizer = gestureRecognizer
            keyboardWindow.addGestureRecognizer(gestureRecognizer)
        }
        
        var firstResponderView: UIView?
        for surface in self.surfaces {
            if hasFirstResponder(surface.host) {
                firstResponderView = surface.host
                break
            }
        }
        
        if let firstResponderView = firstResponderView {
            let containerOrigin = firstResponderView.convert(CGPoint(), to: nil)
            let horizontalTranslation = CATransform3DMakeTranslation(containerOrigin.x, 0.0, 0.0)
            keyboardWindow.layer.sublayerTransform = horizontalTranslation
            if let tracingLayer = firstResponderView.layer as? CATracingLayer {
                if let previousPositionAnimationMirrorSource = self.previousPositionAnimationMirrorSource, previousPositionAnimationMirrorSource !== tracingLayer {
                    previousPositionAnimationMirrorSource.setPositionAnimationMirrorTarget(nil)
                }
                tracingLayer.setPositionAnimationMirrorTarget(keyboardWindow.layer)
                self.previousPositionAnimationMirrorSource = tracingLayer
            } else if let previousPositionAnimationMirrorSource = self.previousPositionAnimationMirrorSource {
                previousPositionAnimationMirrorSource.setPositionAnimationMirrorTarget(nil)
                self.previousPositionAnimationMirrorSource = nil
            }
        } else {
            keyboardWindow.layer.sublayerTransform = CATransform3DIdentity
            if let previousPositionAnimationMirrorSource = self.previousPositionAnimationMirrorSource {
                previousPositionAnimationMirrorSource.setPositionAnimationMirrorTarget(nil)
                self.previousPositionAnimationMirrorSource = nil
            }
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
    
    @objc func minimizeGesture(_ recognizer: UISwipeGestureRecognizer) {
        if case .ended = recognizer.state {
            self.minimized = !self.minimized
            self.minimizedUpdated?()
        }
    }
}
