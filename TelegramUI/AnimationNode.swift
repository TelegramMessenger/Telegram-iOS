import Foundation
import AsyncDisplayKit
import Lottie

final class AnimationNode : ASDisplayNode {
    private let scale: CGFloat
    var played = false
    var completion: (() -> Void)?
    
    init(animation: String, keysToColor: [String]?, color: UIColor, scale: CGFloat) {
        self.scale = scale
        
        super.init()
        
        self.setViewBlock({
            if let url = frameworkBundle.url(forResource: animation, withExtension: "json"), let composition = LOTComposition(filePath: url.path) {
                let view = LOTAnimationView(model: composition, in: frameworkBundle)
                view.backgroundColor = .clear
                view.isOpaque = false
                
                let colorCallback = LOTColorValueCallback(color: color.cgColor)
                if let keysToColor = keysToColor {
                    for key in keysToColor {
                        view.setValueDelegate(colorCallback, for: LOTKeypath(string: "\(key).Color"))
                    }
                }
                
                return view
            } else {
                return UIView()
            }
        })
    }
    
    func animationView() -> LOTAnimationView? {
        return self.view as? LOTAnimationView
    }
    
    func play() {
        if let animationView = animationView(), !animationView.isAnimationPlaying, !self.played {
            self.played = true
            animationView.play { [weak self] _ in
                self?.completion?()
            }
        }
    }
    
    func reset() {
        if self.played, let animationView = animationView() {
            self.played = false
            animationView.stop()
        }
    }
    
    func preferredSize() -> CGSize? {
        if let animationView = animationView(), let sceneModel = animationView.sceneModel {
            return CGSize(width: sceneModel.compBounds.width * self.scale, height: sceneModel.compBounds.height * self.scale)
        } else {
            return nil
        }
    }
}
