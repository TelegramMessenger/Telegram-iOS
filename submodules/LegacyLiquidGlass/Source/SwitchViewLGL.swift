import UIKit

open class SwitchViewLGL: UISwitch {

    enum IsOnStrategy {
        case toches
        case tracking
        case endTracking
        case none
    }

    // MARK: - Property

    private var liquidGlassLensView = LensViewLGL()

    private var thumbView: UIView?

    private let generator = UIImpactFeedbackGenerator(style: .light)

    private var currentLensAnimator: UIViewPropertyAnimator?

    private var isOnStrategy: IsOnStrategy = .none
    private var isChangedTogled = false

    private var animated = true

    // MARK: - LifeCycle

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    open override func setOn(_ on: Bool, animated: Bool) {
        super.setOn(on, animated: animated)
        let targetX = on ? bounds.width : 0
        switch isOnStrategy {
        case .toches, .endTracking:
            if animated {
                currentLensAnimator?.stopAnimation(false)
                currentLensAnimator?.finishAnimation(at: .current)
                currentLensAnimator = UIViewPropertyAnimator(duration: 0.3, curve: .linear) { [weak self] in
                    self?.updateLensPosition(with: targetX)
                }
                currentLensAnimator?.addCompletion { [weak self] position in
                    self?.liquidLens(false)
                }
                currentLensAnimator?.startAnimation()
            } else {
                updateLensPosition(with: targetX)
                liquidLens(false)
            }
        case .tracking:
            if animated {
                UIView.animate(withDuration: 0.2) { [weak self] in
                    self?.updateLensPosition(with: targetX)
                }
            } else {
                updateLensPosition(with: targetX)
            }
        case .none:
            break
        }
    }

    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        liquidLens()
    }

    deinit {
        currentLensAnimator?.stopAnimation(false)
        currentLensAnimator = nil
    }
}

// MARK: - UI

private extension SwitchViewLGL {

    func setupUI() {
        layer.shadowOpacity = 0

        liquidGlassLensView.frame = CGRect(x: 0, y: 0, width: 44, height: 31)
        addSubview(liquidGlassLensView)
        updateLensPosition(with: isOn ? bounds.width : 0)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)

        let longPressGesture = UILongPressGestureRecognizer()
        longPressGesture.minimumPressDuration = 0
        longPressGesture.addTarget(self, action: #selector(handleLongPress(_:)))
        longPressGesture.require(toFail: panGesture)
        addGestureRecognizer(longPressGesture)

        setupThumbView()
    }
}

// MARK: - Thumb

private extension SwitchViewLGL {

    func setupThumbView() {
        if let thumbView = findThumbView(in: self) {
            self.thumbView = thumbView
        } else {
            print("Error: Can't find thumb in the switch view")
        }
    }

    func findThumbView(in view: UIView) -> UIView? {
        if isThumbLikeView(view) && !(view is LensViewLGL) {
            return view
        }
        for subview in view.subviews {
            if isThumbLikeView(subview) && !(subview is LensViewLGL) {
                return subview
            }
            if isThumbContainer(subview) {
                if let thumb = findThumbInContainer(subview) {
                    return thumb
                }
            }
            if let found = findThumbView(in: subview) {
                return found
            }
        }
        return nil
    }

    func isThumbLikeView(_ view: UIView) -> Bool {
        let width = view.bounds.width
        let height = view.bounds.height
        let isSquare = abs(width - height) < 5
        let isThumbSize = (width >= 20 && width <= 50) && (height >= 20 && height <= 50)
        let isRound = view.layer.cornerRadius > width / 4
        let hasShadow = view.layer.shadowOpacity > 0
        let isImageView = view is UIImageView
        return isSquare && isThumbSize && (isRound || hasShadow || isImageView)
    }

    func isThumbContainer(_ view: UIView) -> Bool {
        let width = view.bounds.width
        let height = view.bounds.height
        return (width >= 45 && width <= 60) &&
               (height >= 25 && height <= 35) &&
               view.layer.cornerRadius > 0
    }

    func findThumbInContainer(_ container: UIView) -> UIView? {
        var candidates = [(view: UIView, roundness: CGFloat, hasShadow: Bool)]()
        func searchInContainer(_ view: UIView) {
            for subview in view.subviews {
                let width = subview.bounds.width
                let roundness = subview.layer.cornerRadius / max(width / 2, 0.1)
                let hasShadow = subview.layer.shadowOpacity > 0
                if width >= 20 && width <= 50 &&
                   abs(width - subview.bounds.height) < 5 &&
                   !(subview is LensViewLGL) {
                    candidates.append((subview, roundness, hasShadow))
                }
                searchInContainer(subview)
            }
        }
        searchInContainer(container)
        if let thumb = candidates.max(by: {
            if $0.hasShadow != $1.hasShadow {
                return $1.hasShadow
            }
            return $0.roundness < $1.roundness
        })?.view {
            return thumb
        }
        return nil
    }
}

// MARK: - GestureRecognizer

private extension SwitchViewLGL {

    @objc func handleLongPress(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .ended:
            setupIsOn(strategy: .toches)
        default:
            break
        }
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            liquidLens()
        case .changed:
            let targetX = gesture.location(in: self).x
            if targetX <= 2 && isOn || targetX >= (bounds.width - 2) && !isOn {
                isChangedTogled = true
                setupIsOn(strategy: .tracking)
            } else {
                updateLensPosition(with: targetX)
                liquidGlassLensView.animateLensSquash(with: gesture.velocity(in: self).x, min: 500, scale: 1.4)
            }
        case .ended, .cancelled, .failed:
            if isChangedTogled {
                let targetX = isOn ? bounds.width : 0
                if animated {
                    UIView.animate(withDuration: 0.2) { [weak self] in
                        self?.updateLensPosition(with: targetX)
                    } completion: { [weak self] _ in
                        self?.isChangedTogled = false
                        self?.liquidLens(false)
                    }
                } else {
                    updateLensPosition(with: targetX)
                    isChangedTogled = false
                    liquidLens(false)
                }
            } else {
                setupIsOn(strategy: .endTracking)
                isChangedTogled = false
            }
        default:
            break
        }
    }

    func setupIsOn(strategy: IsOnStrategy) {
        generator.impactOccurred(intensity: 1)
        isOnStrategy = strategy
        isOn.toggle()
    }
}

// MARK: - LiquidGlass

private extension SwitchViewLGL {

    func liquidLens(_ isShow: Bool = true) {
        if isShow {
            if thumbView == nil {
                thumbTintColor = .clear
            } else {
                thumbView?.layer.opacity = 0
            }
            self.liquidGlassLensView.showLens(animated: animated)
        } else {
            self.liquidGlassLensView.hideLens(animated: animated, completion: { [weak self] in
                if self?.thumbView == nil {
                    self?.thumbTintColor = .white
                } else {
                    self?.thumbView?.layer.opacity = 1
                }
            })
        }
    }

    func updateLensPosition(with targetX: Double) {
        liquidGlassLensView.layer.position.x = min(max(targetX, 15), bounds.width - 15)
    }
}
