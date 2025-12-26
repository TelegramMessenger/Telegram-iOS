import UIKit
import LegacyLiquidGlass

open class HighlightTrackingButton: UIButton {

    private var backgroundViewLGL: BackgroundViewLGL?

    private var internalHighlighted = false
    
    public var internalHighligthedChanged: (Bool) -> Void = { _ in }
    public var highligthedChanged: (Bool) -> Void = { _ in }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        if !self.internalHighlighted {
            self.internalHighlighted = true
            self.highligthedChanged(true)
            self.internalHighligthedChanged(true)
        }
        
        if let backgroundViewLGL = self.backgroundViewLGL {
            let location = touch.location(in: backgroundViewLGL)
            backgroundViewLGL.handleLongPressBegan(at: location)
        }

        return super.beginTracking(touch, with: event)
    }
    
    open override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        if self.internalHighlighted {
            self.internalHighlighted = false
            self.highligthedChanged(false)
            self.internalHighligthedChanged(false)
        }

        if let backgroundViewLGL = self.backgroundViewLGL,
           let touch = touch {
            let location = touch.location(in: backgroundViewLGL)
            backgroundViewLGL.handleLongPressEnded(at: location)
        }

        super.endTracking(touch, with: event)
    }
    
    open override func cancelTracking(with event: UIEvent?) {
        if self.internalHighlighted {
            self.internalHighlighted = false
            self.highligthedChanged(false)
            self.internalHighligthedChanged(false)
        }

        if let backgroundViewLGL = self.backgroundViewLGL {
            backgroundViewLGL.cancelGestures()
        }

        super.cancelTracking(with: event)
    }
    
    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.internalHighlighted {
            self.internalHighlighted = false
            self.highligthedChanged(false)
            self.internalHighligthedChanged(false)
        }

        if let backgroundViewLGL = self.backgroundViewLGL {
            backgroundViewLGL.cancelGestures()
        }

        super.touchesCancelled(touches, with: event)
    }

    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let backgroundViewLGL = self.backgroundViewLGL,
           let touch = touches.first,
           internalHighlighted {
            let location = touch.location(in: backgroundViewLGL)
            backgroundViewLGL.handleTouchMoved(to: location)
        }

        super.touchesMoved(touches, with: event)
    }

    public func setupBackgroundViewLGL(transformViews: [BackgroundViewLGL.WeakReference<UIView>]) {
        guard self.window != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.setupBackgroundViewLGL(transformViews: transformViews)
            }
            return
        }
        let backgroundViewLGL = BackgroundViewLGL()
        self.backgroundViewLGL = backgroundViewLGL
        backgroundViewLGL.layer.cornerRadius = layer.cornerRadius
        backgroundViewLGL.frame = bounds
        backgroundViewLGL.clipsToBounds = true
        backgroundViewLGL.isUserInteractionEnabled = false
        backgroundViewLGL.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundViewLGL.blurContainer.layer.opacity = 0
        backgroundViewLGL.extraBlur.layer.opacity = 0
        backgroundViewLGL.highlightLayer.opacity = 0
        backgroundViewLGL.borderGradientLayer.opacity = 0
        insertSubview(backgroundViewLGL, at: 0)
        backgroundColor = .clear
        contentVerticalAlignment = .center
        contentHorizontalAlignment = .center
        if let superview = superview {
            backgroundViewLGL.setupSwipeEffect(locationSuperview: superview, transformViews: transformViews)
        }
    }
}
