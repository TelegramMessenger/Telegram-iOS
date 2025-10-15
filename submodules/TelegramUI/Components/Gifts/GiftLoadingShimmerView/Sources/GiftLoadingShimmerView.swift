import UIKit
import Display
import ComponentFlow
import TelegramPresentationData

private final class ShimmerEffectView: UIView {
    private var currentBackgroundColor: UIColor?
    private var currentForegroundColor: UIColor?
    private let imageContainerView: UIView
    private let imageView: UIImageView

    private var absoluteLocation: (CGRect, CGSize)?
    private var shouldBeAnimating = false

    override init(frame: CGRect = .zero) {
        self.imageContainerView = UIView()
        self.imageContainerView.isUserInteractionEnabled = false

        self.imageView = UIImageView()
        self.imageView.isUserInteractionEnabled = false
        self.imageView.contentMode = .scaleToFill

        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.clipsToBounds = true

        self.imageContainerView.addSubview(self.imageView)
        self.addSubview(self.imageContainerView)
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateAnimation()
    }

    func update(backgroundColor: UIColor, foregroundColor: UIColor) {
        if let currentBackgroundColor = self.currentBackgroundColor, currentBackgroundColor.argb == backgroundColor.argb,
           let currentForegroundColor = self.currentForegroundColor, currentForegroundColor.argb == foregroundColor.argb {
            return
        }
        self.currentBackgroundColor = backgroundColor
        self.currentForegroundColor = foregroundColor

        self.imageView.image = generateImage(CGSize(width: 4.0, height: 320.0), opaque: true, scale: 1.0, rotatedContext: { size, context in
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: .zero, size: size))

            context.clip(to: CGRect(origin: .zero, size: size))

            let transparentColor = foregroundColor.withAlphaComponent(0.0).cgColor
            let peakColor = foregroundColor.cgColor

            var locations: [CGFloat] = [0.0, 0.5, 1.0]
            let colors: [CGColor] = [transparentColor, peakColor, transparentColor]

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!

            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: [])
        })
    }

    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        if let absoluteLocation, absoluteLocation.0 == rect && absoluteLocation.1 == containerSize {
            return
        }
        let sizeUpdated = self.absoluteLocation?.1 != containerSize
        let frameUpdated = self.absoluteLocation?.0 != rect
        self.absoluteLocation = (rect, containerSize)

        if sizeUpdated, shouldBeAnimating {
            self.imageView.layer.removeAnimation(forKey: "shimmer")
            self.addImageAnimation()
        }

        if frameUpdated {
            self.imageContainerView.frame = CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize)
        }

        self.updateAnimation()
    }

    private func updateAnimation() {
        let inHierarchy = (self.window != nil)
        let shouldAnimate = inHierarchy && (self.absoluteLocation != nil)
        if shouldAnimate != self.shouldBeAnimating {
            self.shouldBeAnimating = shouldAnimate
            if shouldAnimate {
                self.addImageAnimation()
            } else {
                self.imageView.layer.removeAnimation(forKey: "shimmer")
            }
        }
    }
    
    private func addImageAnimation() {
        guard let containerSize = self.absoluteLocation?.1 else { return }
        let gradientHeight: CGFloat = 250.0
        self.imageView.frame = CGRect(origin: CGPoint(x: 0.0, y: -gradientHeight),
                                      size: CGSize(width: containerSize.width, height: gradientHeight))
        
        let anim = CABasicAnimation(keyPath: "position.y")
        anim.fromValue = 0.0
        anim.toValue = (containerSize.height + gradientHeight)
        anim.duration = 1.3
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        anim.fillMode = .removed
        anim.isRemovedOnCompletion = true
        anim.repeatCount = .infinity
        anim.beginTime = CACurrentMediaTime() + 1.0
        anim.isAdditive = true
        
        self.imageView.layer.add(anim, forKey: "shimmer")
    }
}

public final class GiftLoadingShimmerView: UIView {
    private let backgroundView = UIView()
    private let effectView = ShimmerEffectView()
    private let maskImageView = UIImageView()
    
    private var currentParams: (size: CGSize, theme: PresentationTheme, showFilters: Bool)?
    
    public override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear
        self.layer.allowsGroupOpacity = true
        
        self.addSubview(self.backgroundView)
        self.addSubview(self.effectView)
        self.addSubview(self.maskImageView)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    public func update(size: CGSize, theme: PresentationTheme, showFilters: Bool = false, isPlain: Bool = false, transition: ContainedViewLayoutTransition) {
        let backgroundColor = isPlain ? theme.list.itemBlocksBackgroundColor : theme.list.blocksBackgroundColor
        let color = theme.list.itemSecondaryTextColor.mixedWith(theme.list.blocksBackgroundColor, alpha: 0.85)
        
        if self.currentParams?.size != size || self.currentParams?.theme !== theme || self.currentParams?.showFilters != showFilters {
            self.currentParams = (size, theme, showFilters)
            
            self.backgroundView.backgroundColor = color
            
            self.maskImageView.image = generateImage(size, rotatedContext: { size, context in
                context.setFillColor(backgroundColor.cgColor)
                context.fill(CGRect(origin: .zero, size: size))
                
                let sideInset: CGFloat = 16.0
                
                if showFilters {
                    let filterSpacing: CGFloat = 6.0
                    let filterWidth = (size.width - sideInset * 2.0 - filterSpacing * 3.0) / 4.0
                    for i in 0 ..< 4 {
                        let rect = CGRect(origin: CGPoint(x: sideInset + (filterWidth + filterSpacing) * CGFloat(i), y: 0.0),
                                          size: CGSize(width: filterWidth, height: 28.0))
                        context.addPath(CGPath(roundedRect: rect, cornerWidth: 14.0, cornerHeight: 14.0, transform: nil))
                    }
                }
                
                var currentY: CGFloat = 39.0 + 7.0
                var rowIndex: Int = 0
                
                let optionSpacing: CGFloat = 10.0
                let optionWidth = (size.width - sideInset * 2.0 - optionSpacing * 2.0) / 3.0
                let itemSize = CGSize(width: optionWidth, height: 154.0)
                
                context.setBlendMode(.copy)
                context.setFillColor(UIColor.clear.cgColor)
                
                while currentY < size.height {
                    for i in 0 ..< 3 {
                        let itemOrigin = CGPoint(
                            x: sideInset + CGFloat(i) * (itemSize.width + optionSpacing),
                            y: 39.0 + 9.0 + CGFloat(rowIndex) * (itemSize.height + optionSpacing)
                        )
                        context.addPath(CGPath(roundedRect: CGRect(origin: itemOrigin, size: itemSize),
                                               cornerWidth: 10.0, cornerHeight: 10.0, transform: nil))
                    }
                    currentY += itemSize.height
                    rowIndex += 1
                }
                context.fillPath()
            })
            
            self.effectView.update(backgroundColor: color, foregroundColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4))
            self.effectView.updateAbsoluteRect(CGRect(origin: .zero, size: size), within: size)
        }
        
        transition.updateFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: size))
        transition.updateFrame(view: self.maskImageView, frame: CGRect(origin: .zero, size: size))
        transition.updateFrame(view: self.effectView, frame: CGRect(origin: .zero, size: size))
    }
}

