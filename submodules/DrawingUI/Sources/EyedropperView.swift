import Foundation
import UIKit
import Display
import SwiftSignalKit

private let size = CGSize(width: 148.0, height: 148.0)
private let outerWidth: CGFloat = 12.0
private let ringWidth: CGFloat = 5.0
private let selectionWidth: CGFloat = 4.0

private func generateShadowImage(size: CGSize) -> UIImage? {
    let inset: CGFloat = 60.0
    let imageSize = CGSize(width: size.width + inset * 2.0, height: size.height + inset * 2.0)
    return generateImage(imageSize, rotatedContext: { imageSize, context in
        context.clear(CGRect(origin: .zero, size: imageSize))
        
        context.setShadow(offset: CGSize(width: 0.0, height: 0.0), blur: 40.0, color: UIColor(rgb: 0x000000, alpha: 0.9).cgColor)
        context.setFillColor(UIColor(rgb: 0x000000, alpha: 0.1).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: inset, y: inset), size: size))
    })
}

private func generateGridImage(size: CGSize, light: Bool) -> UIImage? {
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        context.setFillColor(light ? UIColor.white.cgColor : UIColor(rgb: 0x505050).cgColor)
        
        let lineWidth: CGFloat = 1.0
        var offset: CGFloat = 7.0
        for _ in 0 ..< 8 {
            context.fill(CGRect(origin: CGPoint(x: 0.0, y: offset), size: CGSize(width: size.width, height: lineWidth)))
            context.fill(CGRect(origin: CGPoint(x: offset, y: 0.0), size: CGSize(width: lineWidth, height: size.height)))
            
            offset += 14.0
        }
    })
}

final class EyedropperView: UIView {
    private weak var drawingView: DrawingView?
    
    private let containerView: UIView
    private let shadowLayer: SimpleLayer
    private let clipView: UIView
    private let zoomedView: UIImageView
    
    private let gridLayer: SimpleLayer
    
    private let outerColorLayer: SimpleLayer
    private let ringLayer: SimpleLayer
    private let selectionLayer: SimpleLayer
    
    private let sourceImage: (data: Data, size: CGSize, bytesPerRow: Int, info: CGBitmapInfo)?
    
    var completed: (DrawingColor) -> Void = { _ in }
    var dismissed: () -> Void = { }
    
    init(containerSize: CGSize, drawingView: DrawingView, sourceImage: UIImage) {
        self.drawingView = drawingView
        
        self.zoomedView = UIImageView(image: sourceImage)
        self.zoomedView.isOpaque = true
        self.zoomedView.layer.magnificationFilter = .nearest
        
        if let cgImage = sourceImage.cgImage, let pixelData = cgImage.dataProvider?.data as? Data {
            self.sourceImage = (pixelData, sourceImage.size, cgImage.bytesPerRow, cgImage.bitmapInfo)
        } else {
            self.sourceImage = nil
        }
        
        let bounds = CGRect(origin: .zero, size: size)
        
        self.containerView = UIView()
        self.containerView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((containerSize.width - size.width) / 2.0), y: floorToScreenPixels((containerSize.height - size.height) / 2.0)), size: size)
        
        self.shadowLayer = SimpleLayer()
        self.shadowLayer.contents = generateShadowImage(size: size)?.cgImage
        self.shadowLayer.frame = bounds.insetBy(dx: -60.0, dy: -60.0)
        
        let clipFrame = bounds.insetBy(dx: outerWidth + ringWidth, dy: outerWidth + ringWidth)
        self.clipView = UIView()
        self.clipView.clipsToBounds = true
        self.clipView.frame = bounds.insetBy(dx: outerWidth + ringWidth, dy: outerWidth + ringWidth)
        self.clipView.layer.cornerRadius = size.width / 2.0 - outerWidth - ringWidth
        if #available(iOS 13.0, *) {
            self.clipView.layer.cornerCurve = .circular
        }
        self.clipView.addSubview(self.zoomedView)
        
        self.gridLayer = SimpleLayer()
        self.gridLayer.opacity = 0.6
       
        self.gridLayer.frame = self.clipView.bounds
        self.gridLayer.contents = generateGridImage(size: clipFrame.size, light: true)?.cgImage
        
        self.outerColorLayer = SimpleLayer()
        self.outerColorLayer.rasterizationScale = UIScreen.main.scale
        self.outerColorLayer.shouldRasterize = true
        self.outerColorLayer.frame = bounds
        self.outerColorLayer.cornerRadius = self.outerColorLayer.frame.width / 2.0
        self.outerColorLayer.borderWidth = outerWidth
        
        self.ringLayer = SimpleLayer()
        self.ringLayer.rasterizationScale = UIScreen.main.scale
        self.ringLayer.shouldRasterize = true
        self.ringLayer.borderColor = UIColor.white.cgColor
        self.ringLayer.frame = bounds.insetBy(dx: outerWidth, dy: outerWidth)
        self.ringLayer.cornerRadius = self.ringLayer.frame.width / 2.0
        self.ringLayer.borderWidth = ringWidth

        self.selectionLayer = SimpleLayer()
        self.selectionLayer.borderColor = UIColor.white.cgColor
        self.selectionLayer.borderWidth = selectionWidth
        self.selectionLayer.cornerRadius = 2.0
        self.selectionLayer.frame = CGRect(origin: CGPoint(x: clipFrame.minX + 48.0, y: clipFrame.minY + 48.0), size: CGSize(width: 17.0, height: 17.0)).insetBy(dx: -UIScreenPixel, dy: -UIScreenPixel)
        
        super.init(frame: .zero)
        
        self.addSubview(self.containerView)
        self.clipView.layer.addSublayer(self.gridLayer)
        
        self.containerView.layer.addSublayer(self.shadowLayer)
        self.containerView.addSubview(self.clipView)
        self.containerView.layer.addSublayer(self.ringLayer)
        self.containerView.layer.addSublayer(self.outerColorLayer)
        self.containerView.layer.addSublayer(self.selectionLayer)
        
        self.containerView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
        self.containerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        self.addGestureRecognizer(panGestureRecognizer)
        
        Queue.mainQueue().justDispatch {
            self.updateColor()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var gridIsLight = true
    private var currentColor: DrawingColor?
    func setColor(_ color: UIColor) {
        self.currentColor = DrawingColor(color: color)
        self.outerColorLayer.borderColor = color.cgColor
        self.selectionLayer.backgroundColor = color.cgColor
        
        if color.lightness > 0.9 {
            self.ringLayer.borderColor = UIColor(rgb: 0x999999).cgColor
            if self.gridIsLight {
                self.gridIsLight = false
                self.gridLayer.contents = generateGridImage(size: self.clipView.frame.size, light: false)?.cgImage
            }
        } else {
            self.ringLayer.borderColor = UIColor.white.cgColor
            if !self.gridIsLight {
                self.gridIsLight = true
                self.gridLayer.contents = generateGridImage(size: self.clipView.frame.size, light: true)?.cgImage
            }
        }
    }
    
    func dismiss() {
        self.containerView.alpha = 0.0
        self.containerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
            self?.removeFromSuperview()
        })
        self.containerView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2)
        self.dismissed()
    }
    
    private func getColorAt(_ point: CGPoint) -> UIColor? {
        guard var sourceImage = self.sourceImage, point.x >= 0 && point.x < sourceImage.size.width && point.y >= 0 && point.y < sourceImage.size.height else {
            return UIColor.black
        }
                
        let x = Int(point.x)
        let y = Int(point.y)
              
        var color: UIColor?
        sourceImage.data.withUnsafeMutableBytes { buffer in
            guard let bytes = buffer.assumingMemoryBound(to: UInt8.self).baseAddress else {
                return
            }
                
            let srcLine = bytes.advanced(by: y * sourceImage.bytesPerRow)
            let srcPixel = srcLine + x * 4
            let r = srcPixel.pointee
            let g = srcPixel.advanced(by: 1).pointee
            let b = srcPixel.advanced(by: 2).pointee
            
            if sourceImage.info.contains(.byteOrder32Little) {
                color = UIColor(red: CGFloat(b) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(r) / 255.0, alpha: 1.0)
            } else {
                color = UIColor(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: 1.0)
            }
        }
        return color
    }
    
    private func updateColor() {
        guard let drawingView = self.drawingView else {
            return
        }
        var point = self.convert(self.containerView.center, to: drawingView)
        point.x /= drawingView.scale
        point.y /= drawingView.scale
        
        let scale: CGFloat = 15.0
        self.zoomedView.transform = CGAffineTransformMakeScale(scale, scale)
        self.zoomedView.center = CGPoint(x: self.clipView.frame.width / 2.0 + (self.zoomedView.bounds.width / 2.0 - point.x) * scale, y: self.clipView.frame.height / 2.0 + (self.zoomedView.bounds.height / 2.0 - point.y) * scale)
        
        if let color = self.getColorAt(point) {
            self.setColor(color)
        }
    }
    
    @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .changed:
            let translation = gestureRecognizer.translation(in: self)
            self.containerView.center = self.containerView.center.offsetBy(dx: translation.x, dy: translation.y)
            gestureRecognizer.setTranslation(.zero, in: self)
            
            self.updateColor()
        case .ended, .cancelled:
            if let color = currentColor {
                self.containerView.alpha = 0.0
                self.containerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                    self?.removeFromSuperview()
                })
                self.containerView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2)
                
                self.completed(color)
            }
        default:
            break
        }
    }
}
