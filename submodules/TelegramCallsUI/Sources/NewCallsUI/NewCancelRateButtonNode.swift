import Foundation
import UIKit
import Display
import AsyncDisplayKit

final class NewCancelRateButtonNode: ASDisplayNode {
    
    private enum Constants {
        static let cornerRadius: CGFloat = 14
    }
    
    private let progressLayer = CAShapeLayer()
    
    private let clearTextLayer = CATextLayer()
    private let purpleTextLayer = CATextLayer()
    
    private let backgroundLayer = CAShapeLayer()
    private let clearMaskLayer = CAShapeLayer()
    private let purpleMaskLayer = CAShapeLayer()
    
    var cancelClosure: (() -> Void)?
    
    private var displayLink: CADisplayLink?
    
    func startDisplayLink() {
        
        stopDisplayLink()
        let displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
        displayLink.add(to: .current, forMode: .common)
        self.displayLink = displayLink
    }
    
    @objc func displayLinkDidFire(_ displayLink: CADisplayLink) {
        guard progressPrecent.roundToDecimal(2) <= 1.000 else {
            stopDisplayLink()
            startClose()
            return
        }

        CATransaction.begin()
        self.updateProgressView()
        self.progressPrecent += 0.05
        CATransaction.commit()
    }
    
    @objc func closeLinkDidFire(_ displayLink: CADisplayLink) {
        guard progressPrecent >= 0.0 else {
            stopDisplayLink()
            cancelClosure?()
            return
        }

        updateForClose()
        progressPrecent -= 0.005
    }
    
    /// invalidate display link if it's non-nil, then set to nil
    func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    override init() {
        super.init()
        clipsToBounds = true
    }
    
    func updateLayout() {
        let backgroundMask = CAShapeLayer()
        backgroundMask.path = UIBezierPath(roundedRect: bounds, cornerRadius: 14).cgPath
        layer.mask = backgroundMask
        self.layer.addSublayer(progressLayer)
        
        let progressMask = CAShapeLayer()
        progressMask.path = UIBezierPath(roundedRect: bounds, cornerRadius: 4).cgPath
        progressLayer.mask = progressMask
        progressLayer.backgroundColor = UIColor.white.cgColor
        
        setupTextLayers()
    }
    
    func startClose() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cancelButtonPressed))
        view.addGestureRecognizer(tapGesture)
        
        let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: bounds.size), cornerRadius: 14).cgPath
        
        backgroundLayer.path = path
        backgroundLayer.fillColor = UIColor.white.withAlphaComponent(0.25).cgColor
        progressPrecent = 1.0
        clearTextLayer.foregroundColor = UIColor.white.cgColor
        layer.insertSublayer(backgroundLayer, at: 0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            let displayLink = CADisplayLink(target: self, selector: #selector(self.closeLinkDidFire))
            displayLink.add(to: .current, forMode: .common)
            self.displayLink = displayLink
        }
    }
    
    func updateForClose() {
        let progress = Double(bounds.width * progressPrecent).roundToDecimal(2)
        let width = Double(bounds.width - progress).roundToDecimal(2)
        
        let progressRect = CGRect(
            origin: CGPoint(x: width, y: 0),
            size: CGSize(width: progress, height: bounds.height)
        )
        
        let leftProgressRect = CGRect(
            origin: CGPoint(x: 0, y: 0),
            size: CGSize(width: width, height: bounds.height)
        )
        
        let purpleMask = self.createMaskLayer(layer: self.purpleMaskLayer, leftProgressRect)
        let clearMask = self.createMaskLayer(layer: self.clearMaskLayer, progressRect)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.progressLayer.frame = progressRect
        self.purpleTextLayer.mask = purpleMask
        self.clearTextLayer.mask = clearMask
        CATransaction.commit()
        
        setNeedsDisplay()
    }
    
    func animateIn() {
        startDisplayLink()
        
        let backgroundAnimation = CABasicAnimation(keyPath: "backgroundColor")
        backgroundAnimation.fromValue = UIColor(hexString: "FF3B30")!.cgColor
        backgroundAnimation.toValue = UIColor.white.cgColor
        backgroundAnimation.duration = 0.39
        progressLayer.add(backgroundAnimation, forKey: nil)
    }
    
    var progressPrecent = 0.0
    
    private func updateProgressView() {
        let progress = Double(bounds.width * progressPrecent).roundToDecimal(2)
        let width = Double(bounds.width - progress).roundToDecimal(2)
        
        let progressRect = CGRect(
            origin: CGPoint(x: width, y: 0),
            size: CGSize(width: progress, height: bounds.height)
        )
        
        let leftProgressRect = CGRect(
            origin: CGPoint(x: 0, y: 0),
            size: CGSize(width: width, height: bounds.height)
        )
                
        let purpleMask = self.createMaskLayer(layer: self.purpleMaskLayer, leftProgressRect)
        let clearMask = self.createMaskLayer(layer: self.clearMaskLayer, progressRect)

        clearTextLayer.isHidden = false
        purpleTextLayer.isHidden = false

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.progressLayer.frame = progressRect
        self.purpleTextLayer.mask = purpleMask
        self.clearTextLayer.mask = clearMask
        CATransaction.commit()
        
        setNeedsDisplay()
    }
   
    private func createMaskLayer(layer: CAShapeLayer, _ holeRect: CGRect) -> CAShapeLayer {
        
        let path = CGMutablePath()
        
        path.addRect(holeRect)
        path.addRect(bounds)
        
        layer.path = path
        layer.fillRule = .evenOdd
        layer.opacity = 1
        
        return layer
    }
    
    @objc
    func cancelButtonPressed() {
        cancelClosure?()
    }
    
    private func setupTextLayers() {
        let string = "Close"
        
        clearTextLayer.string = string
        clearTextLayer.font = Font.semibold(17)
        clearTextLayer.fontSize = CGFloat(17)
        clearTextLayer.alignmentMode = .center
        clearTextLayer.contentsScale = UIScreen.main.scale

        let textSize = clearTextLayer.preferredFrameSize()
        purpleTextLayer.string = string
        purpleTextLayer.font = Font.semibold(17)
        purpleTextLayer.fontSize = CGFloat(17)
        purpleTextLayer.alignmentMode = .center
        purpleTextLayer.contentsScale = UIScreen.main.scale
        
        purpleTextLayer.frame = CGRect(x: 0, y: (bounds.height - textSize.height) / 2, width: bounds.width, height: textSize.height)
        clearTextLayer.frame = CGRect(x: 0, y: (bounds.height - textSize.height) / 2, width: bounds.width, height: textSize.height)
    
        purpleTextLayer.backgroundColor = UIColor.clear.cgColor
        clearTextLayer.backgroundColor = UIColor.clear.cgColor
        
        clearTextLayer.foregroundColor = UIColor.clear.cgColor
        purpleTextLayer.foregroundColor = UIColor(hexString: "A87FE2")!.cgColor
        
        clearTextLayer.isHidden = true
        purpleTextLayer.isHidden = true
        
        layer.addSublayer(clearTextLayer)
        layer.addSublayer(purpleTextLayer)
    }
}

private extension Double {
    func roundToDecimal(_ fractionDigits: Int) -> Double {
        let multiplier = pow(10, Double(fractionDigits))
        return Darwin.round(self * multiplier) / multiplier
    }
}

// new button for animated
class AnimatedButton: UIView {
    enum State: Equatable {
        case collapsed
        case expanded
        case faded
    }

    private struct Constants {
        static let collapsedCornerRadius: CGFloat = 0.49
        static let expandedCornerRadius: CGFloat = 0.35
        static let internalCornerRadius: CGFloat = 0.1
        static let expasionDuration: CGFloat = 0.4
        static let fadeDuration: CGFloat = 3
    }

    let text: String
    let font: UIFont

    var state: State = .collapsed

    var textAttributes: [NSAttributedString.Key: Any] {
      let style = NSMutableParagraphStyle()
      style.alignment = .center
      return [
        .foregroundColor: UIColor.white,
        .backgroundColor: UIColor.clear,
        .font: font,
        .paragraphStyle: style
      ]
    }

    let foregroundLayer = CALayer()
    let foregroundMaskLayer = CAShapeLayer()
    let backgroundLayer = CALayer()
    let backgroundMaskLayer = CAShapeLayer()

    override var frame: CGRect {
        didSet {
            if state == .collapsed {
                collapse()
            } else if state == .expanded {
                expand(animated: false)
            } else {
                fade(animated: false)
            }
        }
    }

    init(text: String, font: UIFont = .systemFont(ofSize: UIFont.systemFontSize)) {
        self.text = text
        self.font = font

        super.init(frame: .zero)

        // Layer setup.
        foregroundLayer.backgroundColor = UIColor.clear.cgColor
        foregroundLayer.mask = foregroundMaskLayer
        layer.addSublayer(foregroundLayer)

        backgroundLayer.backgroundColor = UIColor(
            red: 1, green: 1, blue: 1, alpha: 0.3
        ).cgColor
        backgroundLayer.mask = backgroundMaskLayer
        layer.addSublayer(backgroundLayer)

        layer.masksToBounds = true
        layer.backgroundColor = UIColor.clear.cgColor

        // Expansion.
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap(_:))))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func onTap(_ sender: UIGestureRecognizer) {
        if state == .collapsed {
            state = .expanded
            expand(animated: true)
        } else if state == .expanded {
            state = .faded
            fade(animated: true)
        } else {
            state = .collapsed
            collapse()
        }
    }

    private func collapse() {
        let foregroundPath = UIBezierPath(
            roundedRect: CGRect(
                x: bounds.width - bounds.height,
                y: 0,
                width: bounds.height,
                height: bounds.height
            ),
            cornerRadius: Constants.collapsedCornerRadius * bounds.height
        )

        foregroundLayer.frame = bounds
        foregroundMaskLayer.frame = bounds
        foregroundMaskLayer.path = foregroundPath.cgPath
        layer.cornerRadius = Constants.collapsedCornerRadius * bounds.height

        // Foreground
        let image = UIGraphicsImageRenderer(size: bounds.size)
            .image { context in
                text.draw(
                    in: bounds.offsetBy(
                        dx: 0,
                        dy: (bounds.height - font.lineHeight) / 2.0
                    ),
                    withAttributes: textAttributes
                )
                UIBezierPath(rect: bounds).fill(with: .sourceOut, alpha: 1)
            }
        foregroundLayer.contents = image.cgImage

        // Background
        let subImage = UIGraphicsImageRenderer(size: bounds.size)
            .image { context in
                text.draw(
                    in: bounds.offsetBy(
                        dx: 0,
                        dy: (bounds.height - font.lineHeight) / 2.0
                    ),
                    withAttributes: textAttributes
                )
          }

        backgroundLayer.contents = subImage.cgImage
        backgroundLayer.frame = bounds
        backgroundMaskLayer.frame = bounds
        backgroundLayer.opacity = 0

        let backgroundPath = UIBezierPath(
            roundedRect: bounds, cornerRadius: Constants.internalCornerRadius * bounds.height
        )
        backgroundPath.append(
            UIBezierPath(roundedRect: bounds, cornerRadius: Constants.internalCornerRadius * bounds.height).reversing()
        )

        backgroundMaskLayer.path = backgroundPath.cgPath
    }

    private func expand(animated: Bool) {
        // Corner radius.
        if animated {
            let cornerAnimation = CABasicAnimation(keyPath: "cornerRadius")
            cornerAnimation.fromValue = layer.cornerRadius
            cornerAnimation.toValue = CGFloat(bounds.height * Constants.expandedCornerRadius)
            cornerAnimation.duration = Constants.expasionDuration
            layer.add(cornerAnimation, forKey: nil)
        }
        layer.cornerRadius = CGFloat(bounds.height * Constants.expandedCornerRadius)

        // Grow foreground text layer.
        let foregroundPath = UIBezierPath(
            roundedRect: CGRect(
                x: 0,
                y: 0,
                width: bounds.width,
                height: bounds.height
            ),
            cornerRadius: Constants.internalCornerRadius * bounds.height
        )

        if animated {
            let pathAnim = CABasicAnimation(keyPath: "path")
            pathAnim.fromValue = foregroundMaskLayer.path
            pathAnim.toValue = foregroundPath.cgPath
            pathAnim.duration = Constants.expasionDuration
            pathAnim.fillMode = .backwards
            pathAnim.timingFunction = easeOutTimingFunction
            foregroundMaskLayer.add(pathAnim, forKey: nil)
        }
        foregroundMaskLayer.path = foregroundPath.cgPath
    }

    private func fade(animated: Bool) {
        // Make background text visible.
        backgroundLayer.opacity = 1

        // Collapse foreground text layer.
        let finalPath = UIBezierPath(
            roundedRect: CGRect(
                x: bounds.width,
                y: 0,
                width: bounds.width,
                height: bounds.height
            ),
            cornerRadius: Constants.internalCornerRadius * bounds.height
        )

        if animated {
            let foregroundAnim = CABasicAnimation(keyPath: "path")
            foregroundAnim.fromValue = foregroundMaskLayer.path
            foregroundAnim.toValue = finalPath.cgPath
            foregroundAnim.duration = Constants.fadeDuration
            foregroundAnim.fillMode = .backwards
            foregroundMaskLayer.add(foregroundAnim, forKey: nil)
        }
        foregroundMaskLayer.path = finalPath.cgPath

        // Grow background text layer.
        let finalBackgroundPath = UIBezierPath(
            roundedRect: bounds, cornerRadius: Constants.internalCornerRadius
        )
        finalBackgroundPath.append(finalPath.reversing())

        if animated {
            let backgroundAnim = CABasicAnimation(keyPath: "path")
            backgroundAnim.fromValue = backgroundMaskLayer.path
            backgroundAnim.toValue = finalBackgroundPath.cgPath
            backgroundAnim.duration = Constants.fadeDuration
            backgroundAnim.fillMode = .backwards
            backgroundMaskLayer.add(backgroundAnim, forKey: nil)
        }
        backgroundMaskLayer.path = finalBackgroundPath.cgPath
    }

    // Timing

    private var easeOutTimingFunction: CAMediaTimingFunction = {
        CAMediaTimingFunction(
            controlPoints: 0.3, 0.95, 1, 1
        )
    }()
}
