import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import SceneKit
import GZip
import AppBundle
import LegacyComponents
import AvatarNode
import TelegramCore
import MultilineTextComponent
import TelegramPresentationData
import PremiumStarComponent

private let sceneVersion: Int = 1

public final class BoostHeaderBackgroundComponent: Component {
    let isVisible: Bool
    let hasIdleAnimations: Bool
        
    public init(isVisible: Bool, hasIdleAnimations: Bool) {
        self.isVisible = isVisible
        self.hasIdleAnimations = hasIdleAnimations
    }
    
    public static func ==(lhs: BoostHeaderBackgroundComponent, rhs: BoostHeaderBackgroundComponent) -> Bool {
        return lhs.isVisible == rhs.isVisible && lhs.hasIdleAnimations == rhs.hasIdleAnimations
    }
    
    public final class View: UIView, SCNSceneRendererDelegate {
        private var _ready = Promise<Bool>()
        var ready: Signal<Bool, NoError> {
            return self._ready.get()
        }
                
        private let sceneView: SCNView
        
        private var previousInteractionTimestamp: Double = 0.0
        private var hasIdleAnimations = false
        
        override init(frame: CGRect) {
            self.sceneView = SCNView(frame: CGRect(origin: .zero, size: CGSize(width: 64.0, height: 64.0)))
            self.sceneView.backgroundColor = .clear
            self.sceneView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.sceneView.isUserInteractionEnabled = false
            self.sceneView.preferredFramesPerSecond = 60
            
            super.init(frame: frame)
            
            self.addSubview(self.sceneView)
            
            self.setup()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
                
        private func setup() {
            guard let scene = loadCompressedScene(name: "boost", version: sceneVersion) else {
                return
            }
            
            self.sceneView.scene = scene
            self.sceneView.delegate = self
            
            let _ = self.sceneView.snapshot()
        }
        
        private var didSetReady = false
        public func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
            if !self.didSetReady {
                self.didSetReady = true
                
                Queue.mainQueue().justDispatch {
                    self._ready.set(.single(true))
                }
            }
        }
        
        func update(component: BoostHeaderBackgroundComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.sceneView.bounds = CGRect(origin: .zero, size: CGSize(width: availableSize.width * 2.0, height: availableSize.height))
            if self.sceneView.superview == self {
                self.sceneView.center = CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0)
            }
            
            self.hasIdleAnimations = component.hasIdleAnimations
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
