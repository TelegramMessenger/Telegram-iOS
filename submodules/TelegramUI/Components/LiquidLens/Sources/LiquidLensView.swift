import Foundation
import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent
import LegacyLiquidGlass

private final class RestingBackgroundView: UIVisualEffectView {
    var isDark: Bool?

    static func colorMatrix(isDark: Bool) -> [Float32] {
        if isDark {
            return [1.082, -0.113, -0.011, 0.0, 0.135, -0.034, 1.003, -0.011, 0.0, 0.135, -0.034, -0.113, 1.105, 0.0, 0.135, 0.0, 0.0, 0.0, 1.0, 0.0]
        } else {
            return [1.185, -0.05, -0.005, 0.0, -0.2, -0.015, 1.15, -0.005, 0.0, -0.2, -0.015, -0.05, 1.195, 0.0, -0.2, 0.0, 0.0, 0.0, 1.0, 0.0]
        }
    }

    init() {
        let effect = UIBlurEffect(style: .light)
        super.init(effect: effect)
        
        for subview in self.subviews {
            if subview.description.contains("VisualEffectSubview") {
                subview.isHidden = true
            }
        }
        
        self.clipsToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(isDark: Bool) {
        if self.isDark == isDark {
            return
        }
        self.isDark = isDark
        
        if let sublayer = self.layer.sublayers?[0], let _ = sublayer.filters {
            sublayer.backgroundColor = nil
            sublayer.isOpaque = false
            
            if let classValue = NSClassFromString("CAFilter") as AnyObject as? NSObjectProtocol {
                let makeSelector = NSSelectorFromString("filterWithName:")
                let filter = classValue.perform(makeSelector, with: "colorMatrix").takeUnretainedValue() as? NSObject
                
                if let filter {
                    var matrix: [Float32] = RestingBackgroundView.colorMatrix(isDark: isDark)
                    filter.setValue(NSValue(bytes: &matrix, objCType: "{CAColorMatrix=ffffffffffffffffffff}"), forKey: "inputColorMatrix")
                    sublayer.filters = [filter]
                    sublayer.setValue(1.0, forKey: "scale")
                }
            }
        }
    }
}

public final class LiquidLensView: UIView {
    private struct Params: Equatable {
        var size: CGSize
        var selectionX: CGFloat
        var selectionWidth: CGFloat
        var isDark: Bool
        var isLifted: Bool

        init(size: CGSize, selectionX: CGFloat, selectionWidth: CGFloat, isDark: Bool, isLifted: Bool) {
            self.size = size
            self.selectionX = selectionX
            self.selectionWidth = selectionWidth
            self.isLifted = isLifted
            self.isDark = isDark
        }
    }

    private struct LensParams: Equatable {
        var baseFrame: CGRect
        var isLifted: Bool

        init(baseFrame: CGRect, isLifted: Bool) {
            self.baseFrame = baseFrame
            self.isLifted = isLifted
        }
    }

    private let containerView: UIView
    private let backgroundContainerContainer: UIView
    private let backgroundContainer: GlassBackgroundContainerView
    private let backgroundView: GlassBackgroundView
    private var lensView: UIView?
    private let liftedContainerView: UIView
    public let contentView: UIView
    private let restingBackgroundView: RestingBackgroundView

    private var legacySelectionView: GlassBackgroundView.ContentImageView?
    private var legacyContentMaskView: UIView?
    private var legacyContentMaskBlobView: UIImageView?
    private var legacyLiftedContentBlobMaskView: UIImageView?
    private var legacyLensView: LensViewLGL?
    private var legacyBackgroundView: BackgroundViewLGL?
    
    public var selectedContentView: UIView {
        return self.liftedContainerView
    }

    private var params: Params?
    private var appliedLensParams: LensParams?
    private var isApplyingLensParams: Bool = false
    private var pendingLensParams: LensParams?

    private var shiftPosition: CGPoint = .zero
    private var indicatorStartX = 0.0
    private var dragStartX = 0.0

    private var liftedDisplayLink: SharedDisplayLinkDriver.Link?

    public var selectionX: CGFloat? {
        return self.params?.selectionX
    }

    public var selectionWidth: CGFloat? {
        return self.params?.selectionWidth
    }

    override public init(frame: CGRect) {
        self.containerView = UIView()
        
        self.backgroundContainerContainer = UIView()
        self.backgroundContainer = GlassBackgroundContainerView()
        
        self.backgroundView = GlassBackgroundView()
        
        self.contentView = UIView()
        self.liftedContainerView = UIView()

        self.restingBackgroundView = RestingBackgroundView()

        super.init(frame: frame)
        
        self.backgroundContainerContainer.addSubview(self.backgroundContainer)
        self.addSubview(self.backgroundContainerContainer)
        
        self.backgroundContainer.contentView.addSubview(self.backgroundView)
        self.backgroundView.contentView.addSubview(self.containerView)
        self.containerView.isUserInteractionEnabled = false
        
        if #available(iOS 26.0, *) {
            if let viewClass = NSClassFromString("_UILiquidLensView") as AnyObject as? NSObjectProtocol {
                let allocSelector = NSSelectorFromString("alloc")
                let initSelector = NSSelectorFromString("initWithRestingBackground:")
                let objcAlloc = viewClass.perform(allocSelector).takeUnretainedValue()
                let instance = objcAlloc.perform(initSelector, with: UIView()).takeUnretainedValue()
                self.lensView = instance as? UIView
            }
        }
        
        if let lensView = self.lensView {
            self.backgroundContainer.layer.zPosition = 1
            lensView.layer.zPosition = 10.0
            
            self.liftedContainerView.addSubview(self.restingBackgroundView)
            
            self.containerView.addSubview(self.liftedContainerView)
            self.containerView.addSubview(lensView)
            self.containerView.addSubview(self.contentView)
            
            lensView.perform(NSSelectorFromString("setLiftedContainerView:"), with: self.backgroundContainer.contentView)
            lensView.perform(NSSelectorFromString("setLiftedContentView:"), with: self.liftedContainerView)
            lensView.perform(NSSelectorFromString("setOverridePunchoutView:"), with: self.contentView)
            
            do {
                let selector = NSSelectorFromString("setLiftedContentMode:")
                if let method = lensView.method(for: selector) {
                    typealias ObjCMethod = @convention(c) (AnyObject, Selector, Int32) -> Void
                    let function = unsafeBitCast(method, to: ObjCMethod.self)
                    function(lensView, selector, 1)
                }
            }
            
            do {
                let selector = NSSelectorFromString("setStyle:")
                if let method = lensView.method(for: selector) {
                    typealias ObjCMethod = @convention(c) (AnyObject, Selector, Int32) -> Void
                    let function = unsafeBitCast(method, to: ObjCMethod.self)
                    function(lensView, selector, 1)
                }
            }
            
            do {
                let selector = NSSelectorFromString("setWarpsContentBelow:")
                if let method = lensView.method(for: selector) {
                    typealias ObjCMethod = @convention(c) (AnyObject, Selector, Bool) -> Void
                    let function = unsafeBitCast(method, to: ObjCMethod.self)
                    function(lensView, selector, true)
                }
            }
            
            lensView.setValue(UIColor(white: 0.0, alpha: 0.1), forKey: "restingBackgroundColor")
        } else {
            setupLegacyLiquidGlass()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        legacyBackgroundView?.center = backgroundView.center
    }

    public func update(size: CGSize, selectionX: CGFloat, selectionWidth: CGFloat, isDark: Bool, isLifted: Bool, transition: ComponentTransition) {
        let params = Params(size: size, selectionX: selectionX, selectionWidth: selectionWidth, isDark: isDark, isLifted: isLifted)
        if self.params == params {
            return
        }
        self.update(params: params, transition: transition)
    }

    private func update(transition: ComponentTransition) {
        guard let params = self.params else {
            return
        }
        self.update(params: params, transition: transition)
    }

    private func updateLens(params: LensParams, animated: Bool) {
        guard let lensView = self.lensView else {
            updateLegacyLens(params: params, animated: animated)
            return
        }

        if self.isApplyingLensParams {
            self.pendingLensParams = params
            return
        }
        self.isApplyingLensParams = true
        let previousParams = self.appliedLensParams

        let transition: ComponentTransition = animated ? .easeInOut(duration: 0.3) : .immediate

        if previousParams?.isLifted != params.isLifted {
            let selector = NSSelectorFromString("setLifted:animated:alongsideAnimations:completion:")
            var shouldScheduleUpdate = false
            var didProcessUpdate = false
            self.pendingLensParams = params
            if let lensView = self.lensView, let method = lensView.method(for: selector) {
                typealias ObjCMethod = @convention(c) (AnyObject, Selector, Bool, Bool, @escaping () -> Void, AnyObject?) -> Void
                let function = unsafeBitCast(method, to: ObjCMethod.self)
                function(lensView, selector, params.isLifted, !transition.animation.isImmediate, { [weak self] in
                    guard let self else {
                        return
                    }
                    let liftedInset: CGFloat = params.isLifted ? 4.0 : -4.0
                    lensView.bounds = CGRect(origin: CGPoint(), size: CGSize(width: params.baseFrame.width + liftedInset * 2.0, height: params.baseFrame.height + liftedInset * 2.0))
                    didProcessUpdate = true
                    if shouldScheduleUpdate {
                        DispatchQueue.main.async { [weak self] in
                            guard let self, let pendingLensParams = self.pendingLensParams else {
                                return
                            }
                            self.isApplyingLensParams = false
                            self.pendingLensParams = nil
                            self.updateLens(params: pendingLensParams, animated: !transition.animation.isImmediate)
                        }
                    }
                }, nil)
            }
            if didProcessUpdate {
                transition.animateView {
                    lensView.center = CGPoint(x: params.baseFrame.midX, y: params.baseFrame.midY)
                }
                self.pendingLensParams = nil
                self.isApplyingLensParams = false
            } else {
                shouldScheduleUpdate = true
            }
        } else {
            transition.animateView {
                let liftedInset: CGFloat = params.isLifted ? 4.0 : -4.0
                lensView.bounds = CGRect(origin: CGPoint(), size: CGSize(width: params.baseFrame.width + liftedInset * 2.0, height: params.baseFrame.height + liftedInset * 2.0))
                lensView.center = CGPoint(x: params.baseFrame.midX, y: params.baseFrame.midY)
            }
            self.isApplyingLensParams = false
        }
    }

    private func updateLiftedLensPosition() {
        // Without this, the lens won't update its bouncing animations unless it's being moved
        if self.isApplyingLensParams {
            return
        }
        guard let lensView = self.lensView else {
            return
        }
        guard let params = self.appliedLensParams else {
            return
        }
        lensView.center = CGPoint(x: params.baseFrame.midX, y: params.baseFrame.midY)
    }

    private func update(params: Params, transition: ComponentTransition) {
        let isFirstTime = self.params == nil
        let transition: ComponentTransition = isFirstTime ? .immediate : transition

        self.params = params

        transition.setFrame(view: self.containerView, frame: CGRect(origin: CGPoint(), size: params.size))
        transition.setFrame(view: self.backgroundContainerContainer, frame: CGRect(origin: CGPoint(), size: params.size))

        transition.setFrame(view: self.backgroundContainer, frame: CGRect(origin: CGPoint(), size: params.size))
        self.backgroundContainer.update(size: params.size, isDark: params.isDark, transition: transition)
        
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: params.size))
        self.backgroundView.update(size: params.size, cornerRadius: params.size.height * 0.5, isDark: params.isDark, tintColor: GlassBackgroundView.TintColor.init(kind: .panel, color: UIColor(white: params.isDark ? 0.0 : 1.0, alpha: 0.6)), isInteractive: true, transition: transition)
        
        transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: params.size))
        transition.setFrame(view: self.liftedContainerView, frame: CGRect(origin: CGPoint(), size: params.size))

        let baseLensFrame = CGRect(origin: CGPoint(x: max(0.0, min(params.selectionX, params.size.width - params.selectionWidth)), y: 0.0), size: CGSize(width: params.selectionWidth, height: params.size.height))
        self.updateLens(params: LensParams(baseFrame: baseLensFrame, isLifted: params.isLifted), animated: !transition.animation.isImmediate)
        
        if let legacyContentMaskView = self.legacyContentMaskView {
            transition.setFrame(view: legacyContentMaskView, frame: CGRect(origin: CGPoint(), size: params.size))
        }
        if let legacyContentMaskBlobView = self.legacyContentMaskBlobView, let legacyLiftedContentBlobMaskView = self.legacyLiftedContentBlobMaskView, let legacySelectionView = self.legacySelectionView {
            let lensFrame = baseLensFrame.insetBy(dx: 4.0, dy: 4.0)
            let effectiveLensFrame = lensFrame.insetBy(dx: params.isLifted ? -2.0 : 0.0, dy: params.isLifted ? -2.0 : 0.0)
            
            if legacyContentMaskBlobView.image?.size.height != lensFrame.height {
                legacyContentMaskBlobView.image = generateStretchableFilledCircleImage(diameter: lensFrame.height, color: .black)
                legacyLiftedContentBlobMaskView.image = legacyContentMaskBlobView.image
                legacySelectionView.image = generateStretchableFilledCircleImage(diameter: lensFrame.height, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            transition.setFrame(view: legacyContentMaskBlobView, frame: effectiveLensFrame)
            transition.setFrame(view: legacyLiftedContentBlobMaskView, frame: effectiveLensFrame)
            
            legacySelectionView.tintColor = UIColor(white: params.isDark ? 1.0 : 0.0, alpha: params.isDark ? 0.1 : 0.075)
            transition.setFrame(view: legacySelectionView, frame: effectiveLensFrame)
        }

        transition.setFrame(view: self.restingBackgroundView, frame: CGRect(origin: CGPoint(), size: params.size))
        self.restingBackgroundView.update(isDark: params.isDark)
        transition.setAlpha(view: self.restingBackgroundView, alpha: params.isLifted ? 0.0 : 1.0)

        if params.isLifted {
            if self.liftedDisplayLink == nil {
                self.liftedDisplayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.updateLiftedLensPosition()
                })
            }
        } else if let liftedDisplayLink = self.liftedDisplayLink {
            self.liftedDisplayLink = nil
            liftedDisplayLink.invalidate()
        }
    }
}

// MARK: - LegacyLiquidGlass

extension LiquidLensView {

    private func setupLegacyLiquidGlass() {
        let legacySelectionView = GlassBackgroundView.ContentImageView()
        self.legacySelectionView = legacySelectionView
        self.backgroundView.contentView.insertSubview(legacySelectionView, at: 0)

        let legacyLensView = LensViewLGL()
        self.legacyLensView = legacyLensView
        backgroundView.addSubview(legacyLensView)

        let legacyBackgroundView = BackgroundViewLGL()
        self.legacyBackgroundView = legacyBackgroundView
        legacyBackgroundView.blurContainer.layer.opacity = 0.1
        legacyBackgroundView.highlightLayer.opacity = 0.1
        legacyBackgroundView.frame = backgroundView.bounds
        backgroundView.addSubview(legacyBackgroundView)

        legacyLensView.hiddenViewsDuringRendering = [LensViewLGL.WeakReference(contentView)]
        legacyLensView.viewsToSetSystemBackground = [LensViewLGL.WeakReference(backgroundView)]

        let legacyContentMaskView = UIView()
        legacyContentMaskView.backgroundColor = .white
        self.legacyContentMaskView = legacyContentMaskView
        self.contentView.mask = legacyContentMaskView

        if let filter = CALayer.luminanceToAlpha() {
            legacyContentMaskView.layer.filters = [filter]
        }

        let legacyContentMaskBlobView = UIImageView()
        self.legacyContentMaskBlobView = legacyContentMaskBlobView
        legacyContentMaskView.addSubview(legacyContentMaskBlobView)

        self.containerView.addSubview(self.contentView)

        let legacyLiftedContentBlobMaskView = UIImageView()
        self.legacyLiftedContentBlobMaskView = legacyLiftedContentBlobMaskView
        self.liftedContainerView.mask = legacyLiftedContentBlobMaskView

        self.containerView.addSubview(self.liftedContainerView)
    }

    private func updateLegacyLens(params: LensParams, animated: Bool) {
        guard let legacyLensView = self.legacyLensView,
              let legacySelectionView = self.legacySelectionView,
              let legacyBackgroundView = self.legacyBackgroundView else {
            return
        }

        if !isApplyingLensParams {
            isApplyingLensParams = true
            shiftPosition = backgroundView.layer.position
            legacyBackgroundView.layer.cornerRadius = backgroundView.cornerRadius
        }

        let transition: ComponentTransition = animated ? .easeInOut(duration: 0.3) : .immediate

        if params.isLifted {
            let effectiveLensFrame = params.baseFrame.insetBy(dx: -5.0, dy: -5.0)
            legacyLensView.showLens()
            transition.setAlpha(view: legacySelectionView, alpha: 0)
            transition.setFrame(view: legacySelectionView, frame: effectiveLensFrame)
            transition.setFrame(view: legacyLensView, frame: effectiveLensFrame)
            transition.setAlpha(view: legacyLensView, alpha: 1)
            transition.setBackgroundColor(view: legacyBackgroundView, color: .systemGray
                .withAlphaComponent(0.1))
            transition.setFrame(view: self.backgroundView, frame: self.backgroundView.bounds.insetBy(dx: -1, dy: -1))
        } else {
            transition.setFrame(view: legacyLensView, frame: params.baseFrame)
            transition.setFrame(view: legacySelectionView, frame: params.baseFrame)
            transition.setAlpha(view: legacyLensView, alpha: 0)
            transition.setAlpha(view: legacySelectionView, alpha: 1)
            transition.setFrame(view: self.backgroundView, frame: self.backgroundView.bounds)
            transition.setBackgroundColor(view: legacyBackgroundView, color: .clear) { _ in
                legacyLensView.hideLens()
            }
        }
    }

    public func beganGesture(_ locationX: CGFloat) {
        if #available(iOS 26.0, *) {

        } else {
            startShift(locationX)
        }
    }

    public func changedGesture(_ velocityX: CGFloat, _ locationX: CGFloat) {
        if #available(iOS 26.0, *) {

        } else {
            if abs(velocityX) > 300 {
                legacyLensView?.animateLensSquash(with: velocityX, min: 300, scale: 1.05)
            }
            updateShift(locationX)
        }
    }

    public func endedGesture() {
        if #available(iOS 26.0, *) {

        } else {
            resetShift()
        }
    }

    private func startShift(_ locationX: CGFloat) {
        guard let legacySelectionView = self.legacySelectionView else { return }

        dragStartX = locationX
        indicatorStartX = legacySelectionView.frame.origin.x
    }

    private func updateShift(_ locationX: CGFloat) {
        guard let legacySelectionView = self.legacySelectionView else { return }

        let width: CGFloat = 0
        let maxX = backgroundView.bounds.width - legacySelectionView.bounds.width + width
        var newX = indicatorStartX + locationX - dragStartX
        newX = max(-width, min(maxX, newX))

        let centerX = backgroundView.bounds.width / 2
        let indicatorCenterX = newX + legacySelectionView.bounds.width / 2

        let progress = (indicatorCenterX - centerX) / centerX

        let clampedProgress = max(-1.0, min(1.0, progress))
        let shift = clampedProgress * abs(clampedProgress) * 4

        let tabBarCentrPositionX = shiftPosition.x + shift
        let transition: ComponentTransition = .easeInOut(duration: 0.1)
        transition.setPosition(view: backgroundView, position: CGPoint(x: tabBarCentrPositionX, y: shiftPosition.y))
    }

    private func resetShift() {
        let transition: ComponentTransition = .easeInOut(duration: 0.3)
        transition.setPosition(view: backgroundView, position: shiftPosition)
    }
}
