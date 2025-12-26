import UIKit

open class BackgroundViewLGL: UIView {

    open class WeakReference<T: AnyObject> {
        weak var value: T?
        public init(_ value: T) {
            self.value = value
        }
    }

    // MARK: - Property

    public let blurContainer = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    public let extraBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    public let highlightLayer = CAGradientLayer()

    public let borderGradientLayer = CAGradientLayer()
    private let borderShape = CAShapeLayer()
    private let borderShapeMask = CAShapeLayer()
    private let tintLayer = CALayer()

    private weak var locationSuperview: UIView?
    private var transformViews: [WeakReference<UIView>] = []
    private var currentDragLocation: CGPoint = .zero

    private var longPressGesture: UILongPressGestureRecognizer?
    private var panGesture: UIPanGestureRecognizer?

    private var shiftAnimator: UIViewPropertyAnimator?
    private var shiftCentrPositionX: CGFloat = 0.0

    private var borderDisplayLink: CADisplayLink?

    private var ciContext: CIContext?

    private var isPressed = false
    private var isDragging = false
    private let scale = 1.388

    // MARK: - LifeCycle

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupCiContext()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupCiContext()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateForCurrentInterfaceStyle()
    }

    deinit {
        tearDownBorderDisplayLink()
    }

    public func setupSwipeEffect(locationSuperview: UIView, transformViews: [WeakReference<UIView>] = []) {
        self.locationSuperview = locationSuperview
        self.transformViews = transformViews

        let longPressGesture = UILongPressGestureRecognizer()
        longPressGesture.minimumPressDuration = 0
        longPressGesture.addTarget(self, action: #selector(handleLongPress(_:)))
        longPressGesture.delegate = self
        self.longPressGesture = longPressGesture
        addGestureRecognizer(longPressGesture)

        let panGesture = UIPanGestureRecognizer()
        panGesture.addTarget(self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        self.panGesture = panGesture
        addGestureRecognizer(panGesture)
    }
}

// MARK: - UI

private extension BackgroundViewLGL {

    func setupUI() {
        layer.shouldRasterize = false
        autoresizingMask = [.flexibleWidth, .flexibleHeight]

        blurContainer.frame = bounds
        blurContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurContainer.alpha = 0.8
        blurContainer.layer.opacity = 0
        blurContainer.layer.masksToBounds = true
        addSubview(blurContainer)

        extraBlur.frame = blurContainer.bounds
        extraBlur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        extraBlur.alpha = 0.3
        blurContainer.contentView.addSubview(extraBlur)

        tintLayer.compositingFilter = "overlayBlendMode"
        tintLayer.backgroundColor = UIColor.clear.cgColor
        blurContainer.contentView.layer.addSublayer(tintLayer)

        highlightLayer.opacity = 0.2
        layer.addSublayer(highlightLayer)

        borderGradientLayer.colors = [
            UIColor.label.withAlphaComponent(0.0).cgColor,
            UIColor.label.withAlphaComponent(0.15).cgColor,
            UIColor.label.withAlphaComponent(0.5).cgColor,
            UIColor.label.withAlphaComponent(0.8).cgColor,
            UIColor.label.withAlphaComponent(0.5).cgColor,
            UIColor.label.withAlphaComponent(0.15).cgColor,
            UIColor.label.withAlphaComponent(0.0).cgColor
        ]
        borderGradientLayer.locations = [0, 0.1, 0.4, 0.5, 0.6, 0.9, 1]
        borderGradientLayer.startPoint = CGPoint(x: 0, y: 1)
        borderGradientLayer.endPoint = CGPoint(x: 1, y: 0)
        layer.addSublayer(borderGradientLayer)

        borderShape.lineWidth = 1
        borderShape.fillColor = UIColor.clear.cgColor
        borderShape.strokeColor = UIColor.label.withAlphaComponent(0.3).cgColor
        borderGradientLayer.mask = borderShape

//        borderShapeMask.lineCap = .butt
//        borderShapeMask.lineJoin = .miter
//        borderShapeMask.fillRule = .evenOdd
//        borderShapeMask.lineWidth = 1

        updateForCurrentInterfaceStyle()
    }

    func setupCiContext() {
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            ciContext = CIContext(mtlDevice: metalDevice)
        } else {
            ciContext = CIContext(options: [.useSoftwareRenderer: false])
        }
    }

    func updateLayout() {
        borderGradientLayer.frame = bounds
        borderGradientLayer.cornerRadius = layer.cornerRadius

        let borderShapeRoundedRect = CGRect(x: bounds.minX + layer.borderWidth, y: bounds.minY + layer.borderWidth, width: bounds.width - 2 * layer.borderWidth, height: bounds.height - 2 * layer.borderWidth)
        let borderShapeMinDistance = min(bounds.height, bounds.width)
        let borderShapeCornerRadius = layer.cornerRadius / borderShapeMinDistance * (borderShapeMinDistance - 2 * layer.borderWidth)
        borderShape.path = UIBezierPath(roundedRect: borderShapeRoundedRect, cornerRadius: borderShapeCornerRadius).cgPath

        tintLayer.frame = bounds
        tintLayer.cornerRadius = layer.frame.height / 2

        shiftCentrPositionX = frame.midX
        blurContainer.layer.cornerRadius = layer.cornerRadius
        highlightLayer.frame = bounds
        highlightLayer.cornerRadius = layer.cornerRadius
        borderGradientLayer.frame = bounds
        borderGradientLayer.cornerRadius = layer.cornerRadius
        borderShape.path = UIBezierPath(roundedRect: bounds.insetBy(dx: layer.borderWidth/2, dy: layer.borderWidth/2), cornerRadius: layer.cornerRadius).cgPath
    }

    func updateForCurrentInterfaceStyle() {
        if traitCollection.userInterfaceStyle == .dark {
            highlightLayer.colors = [
                UIColor.white.withAlphaComponent(0.15).cgColor,
                UIColor.white.withAlphaComponent(0.05).cgColor,
                UIColor.clear.cgColor
            ]
        } else {
            highlightLayer.colors = [
                UIColor.white.withAlphaComponent(0.3).cgColor,
                UIColor.white.withAlphaComponent(0.1).cgColor,
                UIColor.clear.cgColor
            ]
        }
    }
}

// MARK: - GestureRecognizer

extension BackgroundViewLGL {

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            isPressed = true
            let scale = scale
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            let transformViews = self.transformViews
            UIView.animate(withDuration: 0.2) { [weak self] in
                for weakRef in transformViews {
                    if let view = weakRef.value {
                        view.transform = transform
                    }
                }
                self?.transform = transform
//                self?.blurContainer.layer.opacity = 0.8
            }
//            showBorderAnimation()
//            if let otherView = findOtherView() {
//                otherView.updateBorderMask()
//            }
        case .ended, .cancelled:
            isPressed = false
            resetStretchEffect()
            tearDownBorderDisplayLink()
//            if let otherView = findOtherView() {
//                otherView.tearDownBorderDisplayLink()
//                otherView.updateBorderMask()
//            }
        default:
            break
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            isDragging = true
            currentDragLocation = gesture.location(in: self)
//            showBorderAnimation()
//            if let otherView = findOtherView() {
//                otherView.showBorderAnimation()
//                otherView.updateBorderMask()
//            }
//            updateAllBackgroundViewMasks()
        case .changed:
            currentDragLocation = gesture.location(in: self)
            if !bounds.contains(currentDragLocation) {
                applyStretchEffect(to: currentDragLocation)
//                updateBorderMask()
            }
        case .ended, .cancelled:
            isDragging = false
            resetStretchEffect()
            tearDownBorderDisplayLink()
//            updateAllBackgroundViewMasks()
        default:
            break
        }
    }

    public func handleLongPressBegan(at point: CGPoint) {
        if let longPressGesture = longPressGesture {
            longPressGesture.state = .began
            handleLongPress(longPressGesture)
        }
    }

    public func handleLongPressEnded(at point: CGPoint) {
        if let longPressGesture = longPressGesture {
            longPressGesture.state = .ended
            handleLongPress(longPressGesture)
        }
    }

    public func handleTouchMoved(to point: CGPoint) {
        if let panGesture = panGesture {
            panGesture.state = .changed
            handlePan(panGesture)
        }
    }

    public func cancelGestures() {
        if let longPressGesture = longPressGesture {
            longPressGesture.state = .cancelled
            handleLongPress(longPressGesture)
        }

        if let panGesture = panGesture {
            panGesture.state = .cancelled
            handlePan(panGesture)
        }
    }
}

// MARK: - ShiftEffect

extension BackgroundViewLGL {

     public func updateShift(for progress: CGFloat) {
        let clampedProgress = max(-1.0, min(1.0, progress))
        let shift = clampedProgress * abs(clampedProgress) * 4

        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            layer.position.x = shiftCentrPositionX + shift
        } else {
            let tabBarCentrPositionX = shiftCentrPositionX + shift
            shiftAnimator?.stopAnimation(false)
            shiftAnimator?.finishAnimation(at: .current)
            shiftAnimator = UIViewPropertyAnimator(duration: 0.15, curve: .linear)
            shiftAnimator?.addAnimations { [weak self] in
                self?.layer.position.x = tabBarCentrPositionX
            }
            shiftAnimator?.startAnimation()
        }
    }

    public func resetShift() {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            layer.position.x = shiftCentrPositionX
        } else {
            let centrPositionX = shiftCentrPositionX
            shiftAnimator?.stopAnimation(false)
            shiftAnimator?.finishAnimation(at: .current)
            shiftAnimator =  UIViewPropertyAnimator(duration: 0.3, curve: .linear)
            shiftAnimator?.addAnimations { [weak self] in
                self?.layer.position.x = centrPositionX
            }
            shiftAnimator?.startAnimation()
        }
    }
}

// MARK: - BorderEfect

extension BackgroundViewLGL {

    func showBorderAnimation() {
        tearDownBorderDisplayLink()
        setupBorderDisplayLink()
    }

    func setupBorderDisplayLink() {
        borderDisplayLink = CADisplayLink(target: self, selector: #selector(updateBorderAnimation))
        borderDisplayLink?.add(to: .main, forMode: .common)

        if #available(iOS 15.0, *) {
            borderDisplayLink?.preferredFrameRateRange = CAFrameRateRange(
                minimum: ProcessInfo.processInfo.isLowPowerModeEnabled ? 15 : 30,
                maximum: ProcessInfo.processInfo.isLowPowerModeEnabled ? 30 : 60,
                preferred: ProcessInfo.processInfo.isLowPowerModeEnabled ? 30 : 60)
        } else {
            let targetFPS = ProcessInfo.processInfo.isLowPowerModeEnabled ? 30 : 60
            let maxDeviceFPS = UIScreen.main.maximumFramesPerSecond
            borderDisplayLink?.preferredFramesPerSecond = min(targetFPS, maxDeviceFPS)
        }
    }

    @objc func updateBorderAnimation() {
        updateBorderMask()
        if let otherView = findOtherView() {
            otherView.updateBorderMask()
        }
    }

    func updateBorderMask() {
        let intersectingButtons = getAllBackgroundView().filter {
            $0 != self && framesIntersect(frame, $0.frame)
        }

        if intersectingButtons.isEmpty {
            borderShapeMask.path = nil
            borderShape.mask = nil
            return
        }

        let maskPath = CGMutablePath()
        maskPath.addRect(bounds)

        for button in intersectingButtons {
            let intersection = frame.intersection(button.frame)
            if !intersection.isEmpty {
                maskPath.addPath(UIBezierPath(roundedRect: convert(intersection, from: superview), cornerRadius: min(layer.cornerRadius, intersection.height / 2)).cgPath)
            }
        }

        borderShapeMask.path = maskPath
        borderShape.mask = borderShapeMask
    }

    func findOtherView() -> BackgroundViewLGL? {
        let allButtons = getAllBackgroundView()
        for button in allButtons {
            if button != self && framesIntersect(frame, button.frame) {
                return button
            }
        }
        return nil
    }

    func getAllBackgroundView() -> [BackgroundViewLGL] {
        func findButtons(in view: UIView?) -> [BackgroundViewLGL] {
            var buttons: [BackgroundViewLGL] = []
            if let swipeButton = view as? BackgroundViewLGL {
                buttons.append(swipeButton)
            }
            if let view = view {
                for subview in view.subviews {
                    buttons.append(contentsOf: findButtons(in: subview))
                }
            }
            return buttons
        }

        return findButtons(in: locationSuperview)
    }

    func updateAllBackgroundViewMasks() {
        for view in getAllBackgroundView() {
            view.updateBorderMask()
            if view != self && view.isPressed {
                view.tearDownBorderDisplayLink()
            }
        }
    }

    func framesIntersect(_ frame1: CGRect, _ frame2: CGRect) -> Bool {
        guard let locationSuperview = self.locationSuperview else { return false }

        let frame1InSuperview = locationSuperview.convert(frame1, from: locationSuperview)
        let frame2InSuperview = locationSuperview.convert(frame2, from: locationSuperview)
        let intersection = frame1InSuperview.intersection(frame2InSuperview)
        return intersection.width > 0.1 && intersection.height > 0.1
    }

    func tearDownBorderDisplayLink() {
        borderDisplayLink?.invalidate()
        borderDisplayLink = nil
    }
}

// MARK: - StretchEffect

private extension BackgroundViewLGL {

    func applyStretchEffect(to touchPoint: CGPoint) {
        guard let locationSuperview = self.locationSuperview else { return }

        let touchInSuperview = convert(touchPoint, to: locationSuperview)
        let centerInSuperview = convert(CGPoint(x: bounds.midX, y: bounds.midY), to: locationSuperview)

        let directionVector = CGVector(dx: touchInSuperview.x - centerInSuperview.x, dy: touchInSuperview.y - centerInSuperview.y)

        let angle = atan2(directionVector.dy, directionVector.dx)
        let distance = sqrt(directionVector.dx * directionVector.dx + directionVector.dy * directionVector.dy)

        let proximity = calculateDirectionProximity(angle: angle)

        let stretchCoefficient = smoothStep(1 - proximity.diagonal)

        let safeAreaFrame = locationSuperview.bounds.inset(by: locationSuperview.safeAreaInsets)
        let stretchLimits = calculateStretchLimits(center: centerInSuperview, angle: angle, safeAreaFrame: safeAreaFrame)
        let distanceRatio = stretchLimits.maxStretchDistance > 0 ? min(distance / stretchLimits.maxStretchDistance, 1.0) : 0
        let effectiveFactor = stretchCoefficient * smoothStep(distanceRatio)

        let stretchAmounts = calculateStretchAmounts(proximity: proximity, stretchCoefficient: stretchCoefficient, effectiveFactor: effectiveFactor)

        let scaleX = scale + stretchAmounts.x * 0.5
        let scaleY = scale + stretchAmounts.y * 0.5
        let translationFactor = 0.04

        let transform = CGAffineTransform(translationX: directionVector.dx * translationFactor, y: directionVector.dy * translationFactor).scaledBy(x: scaleX, y: scaleY)
        for weakRef in transformViews {
            if let view = weakRef.value {
                view.transform = transform
            }
        }
        self.transform = transform
//        highlightLayer.setAffineTransform(CGAffineTransform(scaleX: 1/scaleX, y: 1/scaleY))
    }

    struct StretchLimits {
        let maxLength: CGFloat
        let maxStretchDistance: CGFloat
    }

    func calculateStretchLimits(
        center: CGPoint,
        angle: CGFloat,
        safeAreaFrame: CGRect
    ) -> StretchLimits {
        let screenDiagonal = sqrt(pow(safeAreaFrame.width, 2) + pow(safeAreaFrame.height, 2))
        let maxDistanceToEdge = distanceToSafeAreaEdge(from: center, angle: angle, safeAreaFrame: safeAreaFrame)
        let referenceMaxDistance = max(maxDistanceToEdge, screenDiagonal * 0.5)
        return StretchLimits(maxLength: screenDiagonal,maxStretchDistance: referenceMaxDistance)
    }

    struct DirectionProximity {
        let horizontal: CGFloat
        let vertical: CGFloat
        let diagonal: CGFloat
    }

    func calculateDirectionProximity(angle: CGFloat) -> DirectionProximity {
        let absAngle = abs(angle)
        let diagonalAngle: CGFloat = .pi / 4

        let toHorizontal = min(absAngle, abs(absAngle - .pi))
        let toVertical = abs(absAngle - .pi / 2)
        let toDiagonal = min(abs(absAngle - diagonalAngle), abs(absAngle - (.pi - diagonalAngle)))

        let horizontalProximity = max(0, 1 - (toHorizontal / diagonalAngle))
        let verticalProximity = max(0, 1 - (toVertical / diagonalAngle))
        let diagonalProximity = max(0, 1 - (toDiagonal / diagonalAngle))

        let total = horizontalProximity + verticalProximity + diagonalProximity
        guard total > 0 else { return DirectionProximity(horizontal: 0, vertical: 0, diagonal: 0) }

        return DirectionProximity(horizontal: horizontalProximity / total, vertical: verticalProximity / total, diagonal: diagonalProximity / total)
    }

    func calculateStretchAmounts(
        proximity: DirectionProximity,
        stretchCoefficient: CGFloat,
        effectiveFactor: CGFloat
    ) -> (x: CGFloat, y: CGFloat) {
        let horizontalWeight = proximity.horizontal * stretchCoefficient
        let verticalWeight = proximity.vertical * stretchCoefficient
        let diagonalWeight = proximity.diagonal * (1 - stretchCoefficient)

        let stretchX = effectiveFactor * (
            horizontalWeight * 1.0 +
            verticalWeight * -0.3 +
            diagonalWeight * 0.6)

        let stretchY = effectiveFactor * (
            horizontalWeight * -0.3 +
            verticalWeight * 1.0 +
            diagonalWeight * 0.6)

        return (stretchX, stretchY)
    }

    func smoothStep(_ t: CGFloat) -> CGFloat {
        t * t * (3 - 2 * t)
    }

    func distanceToSafeAreaEdge(from point: CGPoint, angle: CGFloat, safeAreaFrame: CGRect) -> CGFloat {
        let dx = cos(angle)
        let dy = sin(angle)

        var distances: [CGFloat] = []

        if dx > 0 {
            distances.append((safeAreaFrame.maxX - point.x) / dx)
        } else if dx < 0 {
            distances.append((safeAreaFrame.minX - point.x) / dx)
        }

        if dy > 0 {
            distances.append((safeAreaFrame.maxY - point.y) / dy)
        } else if dy < 0 {
            distances.append((safeAreaFrame.minY - point.y) / dy)
        }

        let positiveDistances = distances.filter { $0 > 0 }
        return positiveDistances.min() ?? .greatestFiniteMagnitude
    }

    func resetStretchEffect() {
        let transform: CGAffineTransform = .identity
        let transformViews = self.transformViews
        UIView.animate(
            withDuration: 0.8,
            delay: 0,
            usingSpringWithDamping: 0.4,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction]
        ) { [weak self] in
            for weakRef in transformViews {
                if let view = weakRef.value {
                    view.transform = transform
                }
            }
            self?.transform = .identity
//            self?.highlightLayer.setAffineTransform(.identity)
//            self?.blurContainer.layer.opacity = 0.4
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension BackgroundViewLGL: UIGestureRecognizerDelegate {

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }
}
