import Foundation
import UIKit
import Display
import TelegramCore

final class MediaAreaMaskLayer: CALayer {
    private var params: (referenceSize: CGSize, mediaAreas: [MediaArea])?
    
    func update(referenceSize: CGSize, mediaAreas: [MediaArea], borderMaskLayer: CALayer?) {
        guard referenceSize != self.params?.referenceSize && mediaAreas != self.params?.mediaAreas else {
            return
        }
        
        for mediaArea in mediaAreas {
            let size = CGSize(width: mediaArea.coordinates.width / 100.0 * referenceSize.width, height: mediaArea.coordinates.height / 100.0 * referenceSize.height)
            let position = CGPoint(x: mediaArea.coordinates.x / 100.0 * referenceSize.width, y: mediaArea.coordinates.y / 100.0 * referenceSize.height)
            let cornerRadius: CGFloat
            if let radius = mediaArea.coordinates.cornerRadius {
                cornerRadius = radius / 100.0 * size.width
            } else {
                cornerRadius = size.height * 0.18
            }
            
            let layer = CALayer()
            layer.backgroundColor = UIColor.white.cgColor
            layer.bounds = CGRect(origin: .zero, size: size)
            layer.position = position
            layer.cornerRadius = cornerRadius
            layer.transform = CATransform3DMakeRotation(mediaArea.coordinates.rotation * Double.pi / 180.0, 0.0, 0.0, 1.0)
            self.addSublayer(layer)
            
            if let borderMaskLayer {
                let borderLayer = CAShapeLayer()
                borderLayer.strokeColor = UIColor.white.cgColor
                borderLayer.fillColor = UIColor.clear.cgColor
                borderLayer.lineWidth = 2.0
                borderLayer.path = CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                borderLayer.bounds = CGRect(origin: .zero, size: size)
                borderLayer.position = position
                borderLayer.transform = layer.transform
                borderMaskLayer.addSublayer(borderLayer)
            }
        }
    }
}
