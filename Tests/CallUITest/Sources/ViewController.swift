import Foundation
import UIKit
import MetalEngine
import Display
import DustEffect

public final class ViewController: UIViewController {
    private var dustLayer: DustEffectLayer?
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.layer.addSublayer(MetalEngine.shared.rootLayer)
        MetalEngine.shared.rootLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -101.0), size: CGSize(width: 100.0, height: 100.0))
        
        self.reset()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageTap(_:))))
        
        self.view.backgroundColor = .white
        
        SharedDisplayLinkDriver.shared.updateForegroundState(true)
    }
    
    func reset() {
        self.dustLayer?.removeFromSuperlayer()
        
        let dustLayer = DustEffectLayer()
        self.dustLayer = dustLayer
        dustLayer.frame = self.view.bounds
        
        self.view.layer.addSublayer(dustLayer)
    }
    
    @objc private func imageTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            guard let dustLayer else {
                return
            }
            
            let image = UIImage(named: "test")!
            let itemSize = CGSize(width: 200.0, height: 200.0)
            let itemFrame = CGRect(origin: CGPoint(x: floor((self.view.bounds.width - itemSize.width) * 0.5), y: floor((self.view.bounds.height - itemSize.height) * 0.5)), size: itemSize)
            dustLayer.addItem(frame: itemFrame, image: image)
        }
    }
}
