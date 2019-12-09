import Foundation
import UIKit
import AsyncDisplayKit
import Lottie
import AppBundle

public final class AnimationNode : ASDisplayNode {
    private let scale: CGFloat
    public var speed: CGFloat = 1.0 {
        didSet {
            if let animationView = animationView() {
                animationView.animationSpeed = speed
            }
        }
    }
    
    private var colorCallbacks: [LOTColorValueCallback] = []
    
    public var played = false
    public var completion: (() -> Void)?
    
    public init(animation: String? = nil, colors: [String: UIColor]? = nil, scale: CGFloat = 1.0) {
        self.scale = scale
        
        super.init()
        
        self.setViewBlock({
            if let animation = animation, let url = getAppBundle().url(forResource: animation, withExtension: "json"), let composition = LOTComposition(filePath: url.path) {
                let view = LOTAnimationView(model: composition, in: getAppBundle())
                view.animationSpeed = self.speed
                view.backgroundColor = .clear
                view.isOpaque = false
                                
                if let colors = colors {
                    for (key, value) in colors {
                        let colorCallback = LOTColorValueCallback(color: value.cgColor)
                        self.colorCallbacks.append(colorCallback)
                        view.setValueDelegate(colorCallback, for: LOTKeypath(string: "\(key).Color"))
                    }
                }
                
                return view
            } else {
                return LOTAnimationView()
            }
        })
    }
    
    public init(animationData: Data, colors: [String: UIColor]? = nil, scale: CGFloat = 1.0) {
        self.scale = scale
        
        super.init()
        
        self.setViewBlock({
            if let json = try? JSONSerialization.jsonObject(with: animationData, options: []) as? [AnyHashable: Any] {
                let composition = LOTComposition(json: json)
                
                let view = LOTAnimationView(model: composition, in: getAppBundle())
                view.animationSpeed = self.speed
                view.backgroundColor = .clear
                view.isOpaque = false
                                
                if let colors = colors {
                    for (key, value) in colors {
                        let colorCallback = LOTColorValueCallback(color: value.cgColor)
                        self.colorCallbacks.append(colorCallback)
                        view.setValueDelegate(colorCallback, for: LOTKeypath(string: "\(key).Color"))
                    }
                }
                
                return view
            } else {
                return LOTAnimationView()
            }
        })
    }
    
    public func setAnimation(name: String) {
        if let url = getAppBundle().url(forResource: name, withExtension: "json"), let composition = LOTComposition(filePath: url.path) {
            self.animationView()?.sceneModel = composition
        }
    }
    
    public func setAnimation(json: [AnyHashable: Any]) {
        self.animationView()?.setAnimation(json: json)
    }
    
    public func animationView() -> LOTAnimationView? {
        return self.view as? LOTAnimationView
    }
    
    public func play() {
        if let animationView = animationView(), !animationView.isAnimationPlaying, !self.played {
            self.played = true
            animationView.play { [weak self] _ in
                self?.completion?()
            }
        }
    }
    
    public func loop() {
        if let animationView = animationView() {
            animationView.loopAnimation = true
            animationView.play()
        }
    }
    
    public func reset() {
        if self.played, let animationView = animationView() {
            self.played = false
            animationView.stop()
        }
    }
    
    public func preferredSize() -> CGSize? {
        if let animationView = animationView(), let sceneModel = animationView.sceneModel {
            return CGSize(width: sceneModel.compBounds.width * self.scale, height: sceneModel.compBounds.height * self.scale)
        } else {
            return nil
        }
    }
}
