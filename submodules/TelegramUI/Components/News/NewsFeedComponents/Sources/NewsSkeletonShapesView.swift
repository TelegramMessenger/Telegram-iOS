import Foundation
import UIKit
import Display
import TelegramPresentationData
import HierarchyTrackingLayer
import NewsFeedSupport

/// Draws skeleton shapes as the mockup does (Feed2 Skeleton.swift:14-45): placeholder-coloured shapes under one
/// diagonal shimmer band, and hairline separators, on the list background. It is Core Animation only: the band moves
/// with a repeating position animation under a shape mask, so the main thread rasterizes nothing.
public final class NewsSkeletonShapesView: UIView {
    private let shapesLayer = CAShapeLayer()
    private let bandContainer = CALayer()
    private let bandMask = CAShapeLayer()
    private let bandLayer = CAGradientLayer()
    private let separatorsLayer = CAShapeLayer()
    /// Core Animation drops the sweep when the view leaves the window or the app goes to the background; it is
    /// added again on the way back (as `ShimmerEffectNode` does).
    private let hierarchyTrackingLayer = HierarchyTrackingLayer()
    private var current: (size: CGSize, shapes: [NewsSkeletonShape], theme: PresentationTheme)?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.layer.addSublayer(self.shapesLayer)
        self.bandContainer.mask = self.bandMask
        self.bandContainer.addSublayer(self.bandLayer)
        self.layer.addSublayer(self.bandContainer)
        self.layer.addSublayer(self.separatorsLayer)
        self.bandLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        self.bandLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        self.layer.addSublayer(self.hierarchyTrackingLayer)
        self.hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
            self?.addSweepIfNeeded()
        }
    }

    /// Left edge from x −420 to W + 200, linearly over 1.5 s, repeating.
    private func addSweepIfNeeded() {
        guard let current = self.current, self.bandLayer.animation(forKey: "sweep") == nil else {
            return
        }
        let sweep = CABasicAnimation(keyPath: "position.x")
        sweep.fromValue = -310.0 as NSNumber
        sweep.toValue = (current.size.width + 310.0) as NSNumber
        sweep.duration = 1.5
        sweep.repeatCount = .infinity
        sweep.timingFunction = CAMediaTimingFunction(name: .linear)
        self.bandLayer.add(sweep, forKey: "sweep")
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    public func update(size: CGSize, shapes: [NewsSkeletonShape], theme: PresentationTheme) {
        if let current = self.current, current.size == size, current.shapes == shapes, current.theme === theme {
            return
        }
        self.current = (size, shapes, theme)

        let fillPath = CGMutablePath()
        let separatorPath = CGMutablePath()
        for shape in shapes {
            switch shape {
            case let .circle(rect):
                fillPath.addEllipse(in: rect)
            case let .roundedRect(rect, cornerRadius):
                // UIBezierPath's rounded rects have continuous corners.
                fillPath.addPath(UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath)
            case let .separator(rect):
                separatorPath.addRect(rect)
            }
        }

        // White at 0.85 on the light theme (the mockup's band); the shimmer colour the skeleton used on dark.
        let bandColor = theme.overallDarkAppearance ? theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4) : UIColor(white: 1.0, alpha: 0.85)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.backgroundColor = theme.list.plainBackgroundColor
        let bounds = CGRect(origin: CGPoint(), size: size)
        self.shapesLayer.frame = bounds
        self.shapesLayer.path = fillPath
        self.shapesLayer.fillColor = theme.list.mediaPlaceholderColor.cgColor
        self.separatorsLayer.frame = bounds
        self.separatorsLayer.path = separatorPath
        // The mockup draws skeleton hairlines lighter than row separators (black 0.08 against 0.12).
        self.separatorsLayer.fillColor = theme.list.itemPlainSeparatorColor.withMultipliedAlpha(2.0 / 3.0).cgColor
        self.bandContainer.frame = bounds
        self.bandMask.frame = bounds
        self.bandMask.path = fillPath
        self.bandLayer.colors = [bandColor.withAlphaComponent(0.0).cgColor, bandColor.cgColor, bandColor.withAlphaComponent(0.0).cgColor]
        // 220 wide, 400 taller than the view and shifted up 200, turned 18° about its centre.
        self.bandLayer.bounds = CGRect(origin: CGPoint(), size: CGSize(width: 220.0, height: size.height + 400.0))
        self.bandLayer.position = CGPoint(x: -310.0, y: size.height * 0.5)
        self.bandLayer.transform = CATransform3DMakeRotation(18.0 * CGFloat.pi / 180.0, 0.0, 0.0, 1.0)
        CATransaction.commit()

        self.bandLayer.removeAnimation(forKey: "sweep")
        self.addSweepIfNeeded()
    }
}
