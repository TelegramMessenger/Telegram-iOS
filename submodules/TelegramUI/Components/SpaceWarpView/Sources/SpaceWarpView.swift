import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow

/*open class SpaceWarpView: UIView {
    private final class WarpPartView: UIView {
        let cloneView: PortalView
        
        init?(contentView: PortalSourceView) {
            guard let cloneView = PortalView(matchPosition: false) else {
                return nil
            }
            self.cloneView = cloneView
            
            super.init(frame: CGRect())
            
            self.layer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            
            self.clipsToBounds = true
            self.addSubview(cloneView.view)
            contentView.addPortal(view: cloneView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(containerSize: CGSize, rect: CGRect, transition: ComponentTransition) {
            transition.setFrame(view: self.cloneView.view, frame: CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: CGSize(width: containerSize.width, height: containerSize.height)))
        }
    }
    
    public var contentView: UIView {
        return self.contentViewImpl
    }
    
    let contentViewImpl: PortalSourceView
    
    private var warpViews: [WarpPartView] = []
    
    override public init(frame: CGRect) {
        self.contentViewImpl = PortalSourceView()
        
        super.init(frame: frame)
        
        self.addSubview(self.contentView)
        self.contentView.alpha = 0.1
        
        for _ in 0 ..< 8 {
            if let warpView = WarpPartView(contentView: self.contentViewImpl) {
                self.warpViews.append(warpView)
                self.addSubview(warpView)
            }
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(size: CGSize, warpHeight: CGFloat, transition: ComponentTransition) {
        transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: size))
        
        let allItemsHeight = warpHeight * 0.5
        for i in 0 ..< self.warpViews.count {
            let itemHeight = warpHeight / CGFloat(self.warpViews.count)
            let itemFraction = CGFloat(i + 1) / CGFloat(self.warpViews.count)
            let _ = itemHeight
            
            let da = CGFloat.pi * 0.5 / CGFloat(self.warpViews.count)
            let alpha = CGFloat.pi * 0.5 - itemFraction * CGFloat.pi * 0.5
            let endPoint = CGPoint(x: cos(alpha), y: sin(alpha))
            let prevAngle = alpha + da
            let prevPt = CGPoint(x: cos(prevAngle), y: sin(prevAngle))
            var angle: CGFloat
            angle = -atan2(endPoint.y - prevPt.y, endPoint.x - prevPt.x)
            
            let itemLengthVector = CGPoint(x: endPoint.x - prevPt.x, y: endPoint.y - prevPt.y)
            let itemLength = sqrt(itemLengthVector.x * itemLengthVector.x + itemLengthVector.y * itemLengthVector.y) * warpHeight * 0.5
            let _ = itemLength
            
            var transform: CATransform3D
            transform = CATransform3DIdentity
            transform.m34 = 1.0 / 240.0
            
            transform = CATransform3DTranslate(transform, 0.0, prevPt.x * allItemsHeight, (1.0 - prevPt.y) * allItemsHeight)
            transform = CATransform3DRotate(transform, angle, 1.0, 0.0, 0.0)
            
            let positionY = size.height - allItemsHeight + 4.0 + CGFloat(i) * itemLength
            let rect = CGRect(origin: CGPoint(x: 0.0, y: positionY), size: CGSize(width: size.width, height: itemLength))
            transition.setPosition(view: self.warpViews[i], position: CGPoint(x: rect.midX, y: 4.0))
            transition.setBounds(view: self.warpViews[i], bounds: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: itemLength)))
            transition.setTransform(view: self.warpViews[i], transform: transform)
            self.warpViews[i].update(containerSize: size, rect: rect, transition: transition)
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self.contentView.hitTest(point, with: event)
    }
}*/

private extension CGPoint {
    static func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func *(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}

private func length(_ v: CGPoint) -> CGFloat {
    return sqrt(v.x * v.x + v.y * v.y)
}

private func normalize(_ v: CGPoint) -> CGPoint {
    let len = length(v)
    return CGPoint(x: v.x / len, y: v.y / len)
}

private struct RippleParams {
    var amplitude: CGFloat
    var frequency: CGFloat
    var decay: CGFloat
    var speed: CGFloat
    
    init(amplitude: CGFloat, frequency: CGFloat, decay: CGFloat, speed: CGFloat) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.decay = decay
        self.speed = speed
    }
}

private func transformCoordinate(
    position: CGPoint,
    origin: CGPoint,
    time: CGFloat,
    params: RippleParams
) -> CGPoint {
    // The distance of the current pixel position from `origin`.
    let distance = length(position - origin)
    
    if distance < 10.0 {
        return position
    }
    
    // The amount of time it takes for the ripple to arrive at the current pixel position.
    let delay = distance / params.speed

    // Adjust for delay, clamp to 0.
    var time = time
    time -= delay
    time = max(0.0, time)

    // The ripple is a sine wave that Metal scales by an exponential decay
    // function.
    let rippleAmount = params.amplitude * sin(params.frequency * time) * exp(-params.decay * time)

    // A vector of length `amplitude` that points away from position.
    let n = normalize(position - origin)

    // Scale `n` by the ripple amount at the current pixel position and add it
    // to the current pixel position.
    //
    // This new position moves toward or away from `origin` based on the
    // sign and magnitude of `rippleAmount`.
    let newPosition = position + n * rippleAmount
    return newPosition
}

private func rectToQuad(
    rect: CGRect,
    quadTL: CGPoint,
    quadTR: CGPoint,
    quadBL: CGPoint,
    quadBR: CGPoint
) -> CATransform3D {
    let x1a = quadTL.x
    let y1a = quadTL.y
    let x2a = quadTR.x
    let y2a = quadTR.y
    let x3a = quadBL.x
    let y3a = quadBL.y
    let x4a = quadBR.x
    let y4a = quadBR.y
    
    let X = rect.origin.x
    let Y = rect.origin.y
    let W = rect.size.width
    let H = rect.size.height
    
    let y21 = y2a - y1a
    let y32 = y3a - y2a
    let y43 = y4a - y3a
    let y14 = y1a - y4a
    let y31 = y3a - y1a
    let y42 = y4a - y2a
    
    let a = -H*(x2a*x3a*y14 + x2a*x4a*y31 - x1a*x4a*y32 + x1a*x3a*y42)
    let b = W*(x2a*x3a*y14 + x3a*x4a*y21 + x1a*x4a*y32 + x1a*x2a*y43)
    let c = H*X*(x2a*x3a*y14 + x2a*x4a*y31 - x1a*x4a*y32 + x1a*x3a*y42) - H*W*x1a*(x4a*y32 - x3a*y42 + x2a*y43) - W*Y*(x2a*x3a*y14 + x3a*x4a*y21 + x1a*x4a*y32 + x1a*x2a*y43)
    
    let d = H*(-x4a*y21*y3a + x2a*y1a*y43 - x1a*y2a*y43 - x3a*y1a*y4a + x3a*y2a*y4a)
    let e = W*(x4a*y2a*y31 - x3a*y1a*y42 - x2a*y31*y4a + x1a*y3a*y42)
    let f = -(W*(x4a*(Y*y2a*y31 + H*y1a*y32) - x3a*(H + Y)*y1a*y42 + H*x2a*y1a*y43 + x2a*Y*(y1a - y3a)*y4a + x1a*Y*y3a*(-y2a + y4a)) - H*X*(x4a*y21*y3a - x2a*y1a*y43 + x3a*(y1a - y2a)*y4a + x1a*y2a*(-y3a + y4a)))
    
    let g = H*(x3a*y21 - x4a*y21 + (-x1a + x2a)*y43)
    let h = W*(-x2a*y31 + x4a*y31 + (x1a - x3a)*y42)
    var i = W*Y*(x2a*y31 - x4a*y31 - x1a*y42 + x3a*y42) + H*(X*(-(x3a*y21) + x4a*y21 + x1a*y43 - x2a*y43) + W*(-(x3a*y2a) + x4a*y2a + x2a*y3a - x4a*y3a - x2a*y4a + x3a*y4a))
    
    let kEpsilon = 0.0001
    
    if fabs(i) < kEpsilon {
        i = kEpsilon * (i > 0 ? 1.0 : -1.0)
    }
    
    //CATransform3D transform = {a/i, d/i, 0, g/i, b/i, e/i, 0, h/i, 0, 0, 1, 0, c/i, f/i, 0, 1.0}
    let transform = CATransform3D(m11: a/i, m12: d/i, m13: 0, m14: g/i, m21: b/i, m22: e/i, m23: 0, m24: h/i, m31: 0, m32: 0, m33: 1, m34: 0, m41: c/i, m42: f/i, m43: 0, m44: 1.0)
    return transform
}

open class SpaceWarpView: UIView {
    private final class GridView: UIView {
        let cloneView: PortalView
        let gridPosition: CGPoint
        
        init?(contentView: PortalSourceView, gridPosition: CGPoint) {
            self.gridPosition = gridPosition
            
            guard let cloneView = PortalView(matchPosition: false) else {
                return nil
            }
            self.cloneView = cloneView
            
            super.init(frame: CGRect())
            
            self.layer.anchorPoint = CGPoint(x: 0.0, y: 0.0)
            
            self.clipsToBounds = true
            self.isUserInteractionEnabled = false
            self.addSubview(cloneView.view)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func updateIsActive(contentView: PortalSourceView, isActive: Bool) {
            if isActive {
                contentView.addPortal(view: self.cloneView)
            } else {
                contentView.removePortal(view: self.cloneView)
            }
        }
        
        func update(containerSize: CGSize, rect: CGRect, transition: ComponentTransition) {
            transition.setFrame(view: self.cloneView.view, frame: CGRect(origin: CGPoint(x: -rect.minX - containerSize.width * 0.5, y: -rect.minY - containerSize.height * 0.5), size: CGSize(width: containerSize.width, height: containerSize.height)))
        }
    }
    
    private var gridViews: [GridView] = []
    
    public var contentView: UIView {
        return self.contentViewImpl
    }
    
    let contentViewImpl: PortalSourceView
    
    private var link: SharedDisplayLinkDriver.Link?
    private var startPoint: CGPoint?
    
    private var timeValue: CGFloat = 0.0
    private var currentActiveViews: Int = 0
    
    private var resolution: (x: Int, y: Int)?
    private var size: CGSize?
    
    override public init(frame: CGRect) {
        self.contentViewImpl = PortalSourceView()
        
        super.init(frame: frame)
        
        self.addSubview(self.contentView)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func trigger(at point: CGPoint) {
        self.startPoint = point
        self.timeValue = 0.0
        
        if self.link == nil {
            self.link = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] deltaTime in
                guard let self else {
                    return
                }
                self.timeValue += deltaTime * (1.0 / CGFloat(UIView.animationDurationFactor()))
                
                if let size = self.size {
                    self.update(size: size, transition: .immediate)
                }
            })
        }
    }
    
    private func updateGrid(resolutionX: Int, resolutionY: Int) {
        if let resolution = self.resolution, resolution.x == resolutionX, resolution.y == resolutionY {
            return
        }
        self.resolution = (resolutionX, resolutionY)
        
        for gridView in self.gridViews {
            gridView.removeFromSuperview()
        }
        
        var gridViews: [GridView] = []
        for y in 0 ..< resolutionY {
            for x in 0 ..< resolutionX {
                if let gridView = GridView(contentView: self.contentViewImpl, gridPosition: CGPoint(x: CGFloat(x) / CGFloat(resolutionX), y: CGFloat(y) / CGFloat(resolutionY))) {
                    gridView.isUserInteractionEnabled = false
                    gridViews.append(gridView)
                    self.addSubview(gridView)
                }
            }
        }
        self.gridViews = gridViews
    }
    
    public func update(size: CGSize, transition: ComponentTransition) {
        self.size = size
        if size.width <= 0.0 || size.height <= 0.0 {
            return
        }
        
        self.updateGrid(resolutionX: max(2, Int(size.width / 100.0)), resolutionY: max(2, Int(size.height / 100.0)))
        guard let resolution = self.resolution else {
            return
        }
        
        //let pixelStep = CGPoint(x: CGFloat(resolution.x) * 0.33, y: CGFloat(resolution.y) * 0.33)
        let pixelStep = CGPoint()
        let itemSize = CGSize(width: size.width / CGFloat(resolution.x), height: size.height / CGFloat(resolution.y))
        
        let params = RippleParams(amplitude: 22.0, frequency: 15.0, decay: 8.0, speed: 1400.0)
        
        var activeViews = 0
        for gridView in self.gridViews {
            let sourceRect = CGRect(origin: CGPoint(x: gridView.gridPosition.x * (size.width + pixelStep.x), y: gridView.gridPosition.y * (size.height + pixelStep.y)), size: itemSize)
            
            gridView.bounds = CGRect(origin: CGPoint(), size: sourceRect.size)
            gridView.update(containerSize: size, rect: sourceRect, transition: transition)
            
            let initialTopLeft = CGPoint(x: sourceRect.minX, y: sourceRect.minY)
            let initialTopRight = CGPoint(x: sourceRect.maxX, y: sourceRect.minY)
            let initialBottomLeft = CGPoint(x: sourceRect.minX, y: sourceRect.maxY)
            let initialBottomRight = CGPoint(x: sourceRect.maxX, y: sourceRect.maxY)
            
            var topLeft = initialTopLeft
            var topRight = initialTopRight
            var bottomLeft = initialBottomLeft
            var bottomRight = initialBottomRight
            
            if let startPoint = self.startPoint {
                topLeft = transformCoordinate(position: topLeft, origin: startPoint, time: self.timeValue, params: params)
                topRight = transformCoordinate(position: topRight, origin: startPoint, time: self.timeValue, params: params)
                bottomLeft = transformCoordinate(position: bottomLeft, origin: startPoint, time: self.timeValue, params: params)
                bottomRight = transformCoordinate(position: bottomRight, origin: startPoint, time: self.timeValue, params: params)
            }
            
            let distanceTopLeft = length(topLeft - initialTopLeft)
            let distanceTopRight = length(topRight - initialTopRight)
            let distanceBottomLeft = length(bottomLeft - initialBottomLeft)
            let distanceBottomRight = length(bottomRight - initialBottomRight)
            var maxDistance = max(distanceTopLeft, distanceTopRight)
            maxDistance = max(maxDistance, distanceBottomLeft)
            maxDistance = max(maxDistance, distanceBottomRight)
            
            let isActive: Bool
            if maxDistance <= 0.5 {
                gridView.layer.transform = CATransform3DIdentity
                isActive = false
            } else {
                let transform = rectToQuad(rect: CGRect(origin: CGPoint(), size: itemSize), quadTL: topLeft, quadTR: topRight, quadBL: bottomLeft, quadBR: bottomRight)
                gridView.layer.transform = transform
                isActive = true
                activeViews += 1
            }
            if gridView.isHidden != !isActive {
                gridView.isHidden = !isActive
                gridView.updateIsActive(contentView: self.contentViewImpl, isActive: isActive)
            }
        }
        
        if self.currentActiveViews != activeViews {
            self.currentActiveViews = activeViews
            #if DEBUG
            print("SpaceWarpView: activeViews = \(activeViews)")
            #endif
        }
    }
    
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.alpha.isZero || self.isHidden || !self.isUserInteractionEnabled {
            return nil
        }
        for view in self.contentView.subviews.reversed() {
            if let result = view.hitTest(self.convert(point, to: view), with: event), result.isUserInteractionEnabled {
                return result
            }
        }
        
        let result = super.hitTest(point, with: event)
        if result != self {
            return result
        } else {
            return nil
        }
    }
}
