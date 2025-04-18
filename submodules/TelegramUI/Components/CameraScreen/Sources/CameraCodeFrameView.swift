import Foundation
import UIKit
import Display
import ComponentFlow
import Camera

final class CameraCodeFrameView: UIView {
    private var cornerLayers: [SimpleShapeLayer] = []
    private let cornerRadius: CGFloat = 12.0
    private let focusedCornerRadius: CGFloat = 6.0
    private let cornerShort: CGFloat = 16.0
    
    private var currentSize: CGSize?
    private var currentRect: CGRect?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
                
        self.isUserInteractionEnabled = false
        
        for _ in 0..<4 {
            let layer = SimpleShapeLayer()
            layer.fillColor = UIColor.clear.cgColor
            layer.strokeColor = UIColor.white.cgColor
            layer.lineWidth = 2.0
            layer.lineCap = .round
            layer.lineJoin = .round
            self.layer.addSublayer(layer)
            self.cornerLayers.append(layer)
        }
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure()
    }
    
    func update(size: CGSize, code: CameraCode?) {
        let isFirstTime = self.currentSize == nil
        self.currentSize = size
        
        var duration: Double = 0.0
        
        let bounds = CGRect(origin: .zero, size: size)
        let rect: CGRect
        if let code {
            let codeRect = code.boundingBox
            let side = max(codeRect.width * bounds.width, codeRect.height * bounds.height) * 0.7
            let center = CGPoint(x: (1.0 - codeRect.center.y) * bounds.width, y: codeRect.center.x * bounds.height)
            rect = CGSize(width: side, height: side).centered(around: center)
            
            if !isFirstTime {
                if let currentRect = self.currentRect {
                    if rect.center.distance(to: currentRect.center) > 40.0 || abs(rect.size.width - currentRect.size.width) > 40.0 {
                        duration = 0.35
                    } else {
                        duration = 0.2
                    }
                } else {
                    duration = 0.4
                }
            }
            self.currentRect = rect
        } else {
            rect = bounds.insetBy(dx: -2.0, dy: -2.0)
            if !isFirstTime {
                duration = 0.4
            }
            self.currentRect = nil
        }
        
        let focused = code != nil
        self.applyPaths(to: self.cornerPaths(for: rect, focused: focused, rotation: 0.0), focused: focused, duration: duration)
    }
    
    private func cornerPaths(for rect: CGRect, focused: Bool, rotation: Double) -> [UIBezierPath] {
        let effectiveCornerRadius = focused ? self.focusedCornerRadius : self.cornerRadius
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: rotation).translatedBy(x: -center.x, y: -center.y)
        
        let topLeftPath = UIBezierPath()
        topLeftPath.move(to: CGPoint(x: rect.minX, y: focused ? rect.minY + self.cornerShort : rect.midY))
        topLeftPath.addLine(to: CGPoint(x: rect.minX, y: rect.minY + effectiveCornerRadius))
        topLeftPath.addQuadCurve(
            to: CGPoint(x: rect.minX + effectiveCornerRadius, y: rect.minY),
            controlPoint: CGPoint(x: rect.minX, y: rect.minY)
        )
        topLeftPath.addLine(to: CGPoint(x: focused ? rect.minX + self.cornerShort : rect.midX, y: rect.minY))
        topLeftPath.apply(transform)
        
        let topRightPath = UIBezierPath()
        topRightPath.move(to: CGPoint(x: rect.maxX, y: focused ? rect.minY + self.cornerShort : rect.midY))
        topRightPath.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + effectiveCornerRadius))
        topRightPath.addQuadCurve(
            to: CGPoint(x: rect.maxX - effectiveCornerRadius, y: rect.minY),
            controlPoint: CGPoint(x: rect.maxX, y: rect.minY)
        )
        topRightPath.addLine(to: CGPoint(x: focused ? rect.maxX - self.cornerShort : rect.midX, y: rect.minY))
        topRightPath.apply(transform)
        
        let bottomRightPath = UIBezierPath()
        bottomRightPath.move(to: CGPoint(x: rect.maxX, y: focused ? rect.maxY - self.cornerShort : rect.midY))
        bottomRightPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - effectiveCornerRadius))
        bottomRightPath.addQuadCurve(
            to: CGPoint(x: rect.maxX - effectiveCornerRadius, y: rect.maxY),
            controlPoint: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        bottomRightPath.addLine(to: CGPoint(x: focused ? rect.maxX - self.cornerShort : rect.midX, y: rect.maxY))
        bottomRightPath.apply(transform)
        
        let bottomLeftPath = UIBezierPath()
        bottomLeftPath.move(to: CGPoint(x: rect.minX, y: focused ? rect.maxY - self.cornerShort : rect.midY))
        bottomLeftPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - effectiveCornerRadius))
        bottomLeftPath.addQuadCurve(
            to: CGPoint(x: rect.minX + effectiveCornerRadius, y: rect.maxY),
            controlPoint: CGPoint(x: rect.minX, y: rect.maxY)
        )
        bottomLeftPath.addLine(to: CGPoint(x: focused ? rect.minX + self.cornerShort : rect.midX, y: rect.maxY))
        bottomLeftPath.apply(transform)
        
        return [topLeftPath, topRightPath, bottomRightPath, bottomLeftPath]
    }
    
    private var animatingAppearance = false
    private func applyPaths(to paths: [UIBezierPath], focused: Bool, duration: Double) {
        let animatingAppearance = self.animatingAppearance
        for (index, path) in paths.enumerated() {
            let layer = self.cornerLayers[index]
            let previousPath = layer.path
            let previousAlpha = layer.opacity
            let previousColor = layer.strokeColor ?? UIColor.clear.cgColor
            let previousLineWidth = layer.lineWidth
            
            if duration > 0.0 && !focused {
                
            } else {
                layer.path = path.cgPath
            }
            layer.opacity = focused ? 1.0 : 0.0
            layer.strokeColor = focused ? UIColor(rgb: 0xf8d74a).cgColor : UIColor.white.cgColor
            layer.lineWidth = focused ? 5.0 : 2.0
            layer.shadowOffset = .zero
            layer.shadowRadius = 1.0
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.2
            
            if duration > 0.0 && !animatingAppearance {
                if focused && previousAlpha.isZero && index == 0 {
                    self.animatingAppearance = true
                }
                if focused {
                    var currentPath = previousPath
                    var duration = duration
                    if let presentationPath = layer.presentation()?.path {
                        currentPath = presentationPath
                        duration *= 0.5
                    }
                    layer.animate(from: currentPath, to: path.cgPath, keyPath: "path", timingFunction: duration > 0.35 ? kCAMediaTimingFunctionSpring : CAMediaTimingFunctionName.linear.rawValue, duration: duration, completion: { _ in
                        if focused && index == 0 {
                            self.animatingAppearance = false
                        }
                    })
                }
                layer.animateAlpha(from: CGFloat(previousAlpha), to: CGFloat(layer.opacity), duration: focused ? 0.4 : 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, completion: !focused ? { finished in
                    layer.path = path.cgPath
                } : nil)
                layer.animate(from: previousColor, to: layer.strokeColor ?? UIColor.white.cgColor, keyPath: "strokeColor", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.3, delay: 0.15)
                layer.animate(from: previousLineWidth, to: layer.lineWidth, keyPath: "lineWidth", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.3)
            }
        }
    }
}

private extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        return sqrt(pow((point.x - self.x), 2) + pow((point.y - self.y), 2))
    }
}
