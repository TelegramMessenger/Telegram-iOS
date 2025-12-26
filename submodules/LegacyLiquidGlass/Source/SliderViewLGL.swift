import UIKit

open class SliderViewLGL: UISlider {

    // MARK: - Property

    private var liquidGlassLensView = LensViewLGL()
    private var thumbView: UIView?
    private var customThumbView: UIView?

    private let generator = UIImpactFeedbackGenerator(style: .light)

    private var previousTouchLocation: CGPoint?
    private var previousTouchTime: TimeInterval?
    private var velocityX: CGFloat = 0.0

    // MARK: - LifeCycle

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    public override func setValue(_ value: Float, animated: Bool) {
        super.setValue(value, animated: animated)
        updateLensPosition()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        updateLensPosition()
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        liquidLens()

        previousTouchLocation = touches.first?.location(in: self)
        previousTouchTime = event?.timestamp
        velocityX = 0.0
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        liquidLens(false)

        previousTouchLocation = nil
        previousTouchTime = nil
        velocityX = 0.0
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)

        guard let touch = touches.first,
              let previousLocation = previousTouchLocation,
              let previousTime = previousTouchTime,
              let event = event else { return }

        let currentLocation = touch.location(in: self)
        let currentTime = event.timestamp
        let deltaX = currentLocation.x - previousLocation.x
        let deltaTime = CGFloat(currentTime - previousTime)
        if deltaTime > 0 {
            velocityX = deltaX / deltaTime
        }

        let trackRect = self.trackRect(forBounds: bounds)
        let newValue = minimumValue + Float((currentLocation.x - trackRect.minX) / trackRect.width) * (maximumValue - minimumValue)
        let clampedValue = min(maximumValue, max(minimumValue, newValue))
        setValue(clampedValue, animated: false)
        sendActions(for: .valueChanged)
        
        liquidGlassLensView.animateLensSquash(with: velocityX, min: 500, scale: 1.4)

        previousTouchLocation = currentLocation
        previousTouchTime = currentTime
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        liquidLens(false)

        previousTouchLocation = nil
        previousTouchTime = nil
        velocityX = 0.0
    }
}

// MARK: - UI

private extension SliderViewLGL {

    func setupUI() {
        layer.shadowOpacity = 0

        liquidGlassLensView.frame = CGRect(x: 0, y: 0, width: 44, height: 31)
        addSubview(liquidGlassLensView)

        updateLensPosition()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.thumbView = self?.setupThumbView()
            self?.customThumbView = self?.setupCustomThumbView()
        }
    }

    func updateLensPosition() {
        let trackRect = self.trackRect(forBounds: bounds)
        let thumbRect = self.thumbRect(forBounds: bounds, trackRect: trackRect, value: value)

        liquidGlassLensView.center = CGPoint(x: thumbRect.midX, y: bounds.midY)
    }

    func updateSliderValue(whith locationX: Double) {
        let trackRect = self.trackRect(forBounds: bounds)
        let newValue = minimumValue + Float((locationX - trackRect.minX) / trackRect.width) * (maximumValue - minimumValue)
        let clampedValue = min(maximumValue, max(minimumValue, newValue))
        setValue(clampedValue, animated: false)
        generator.impactOccurred(intensity: 1)
    }
}

// MARK: - Thumb

private extension SliderViewLGL {

    func setupThumbView() -> UIView? {
        if let thumbView = findThumbView(in: self) {
            return thumbView
        } else {
            print("Error: Can't find thumb in the slider view")
            return nil
        }
    }

    func findThumbView(in view: UIView) -> UIView? {
        for subview in view.subviews {
            if let imageView = subview as? UIImageView,
               imageView.frame.width <= 40 && imageView.frame.height <= 40  {
                return imageView
            }
            if let found = findThumbView(in: subview) {
                return found
            }
        }
        return nil
    }

    func setupCustomThumbView() -> UIView? {
        if let thumbView = findCustomThumb(in: self) {
            return thumbView
        } else {
            return nil
        }
    }

    func findCustomThumb(in view: UIView) -> UIView? {
        for subview in self.subviews {
            if String(describing: type(of: subview)) == "_UISlideriOSVisualElement" {
                for child in subview.subviews {
                    if String(describing: type(of: child)) == "UISliderImageView" {
                        for imageView in child.subviews {
                            if let imgView = imageView as? UIImageView {
                                print("UIImageView: frame=\(imgView.frame), image=\(imgView.image != nil)")
                                if imgView.image != nil &&
                                    imgView.frame.width > 50 &&
                                    imgView.frame.height > 50 &&
                                    imgView.frame.origin.x < 0 {
                                    return imgView
                                }
                            }
                        }
                    }
                }
            }
        }
        return nil
    }
}

// MARK: - LiquidGlass

private extension SliderViewLGL {

    func liquidLens(_ isShow: Bool = true) {
        if isShow {
            if customThumbView == nil {
                if thumbView == nil {
                    thumbTintColor = .clear
                } else {
                    thumbView?.layer.opacity = 0
                }
            } else {
                customThumbView?.layer.opacity = 0
            }
            liquidGlassLensView.showLens(animated: !ProcessInfo.processInfo.isLowPowerModeEnabled)
        } else {
            liquidGlassLensView.hideLens(animated: !ProcessInfo.processInfo.isLowPowerModeEnabled, completion: { [weak self] in
                if self?.customThumbView == nil {
                    if self?.thumbView == nil {
                        self?.thumbTintColor = .white
                    } else {
                        self?.thumbView?.layer.opacity = 1
                    }
                } else {
                    self?.customThumbView?.layer.opacity = 1
                }
            })
        }
    }
}
