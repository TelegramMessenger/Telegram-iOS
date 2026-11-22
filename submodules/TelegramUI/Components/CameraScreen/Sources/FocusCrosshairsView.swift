import Foundation
import UIKit
import Display
import SwiftSignalKit

private let focusAccentColor = UIColor(rgb: 0xf8d74a)
private let indicatorSide: CGFloat = 165.0
private let crosshairsInset: CGFloat = 45.0
private let crosshairsSide: CGFloat = 75.0
private let exposureTrackHeight: CGFloat = 144.0
private let exposureIconSide: CGFloat = 25.0

private func generateCrosshairsImage() -> UIImage? {
    return generateImage(CGSize(width: crosshairsSide, height: crosshairsSide), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        context.setStrokeColor(focusAccentColor.cgColor)
        context.setLineWidth(1.0)
        context.stroke(CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5))
        let tick: CGFloat = 5.0
        context.move(to: CGPoint(x: size.width / 2.0, y: 0.0))
        context.addLine(to: CGPoint(x: size.width / 2.0, y: tick))
        context.move(to: CGPoint(x: size.width / 2.0, y: size.height))
        context.addLine(to: CGPoint(x: size.width / 2.0, y: size.height - tick))
        context.move(to: CGPoint(x: 0.0, y: size.height / 2.0))
        context.addLine(to: CGPoint(x: tick, y: size.height / 2.0))
        context.move(to: CGPoint(x: size.width, y: size.height / 2.0))
        context.addLine(to: CGPoint(x: size.width - tick, y: size.height / 2.0))
        context.strokePath()
    })
}

private func generateExposureIconImage() -> UIImage? {
    return generateImage(CGSize(width: exposureIconSide, height: exposureIconSide), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        context.setFillColor(focusAccentColor.cgColor)
        context.fillEllipse(in: CGRect(x: center.x - 4.5, y: center.y - 4.5, width: 9.0, height: 9.0))
        context.setStrokeColor(focusAccentColor.cgColor)
        context.setLineWidth(1.5)
        context.setLineCap(.round)
        for i in 0 ..< 8 {
            let angle = CGFloat(i) * CGFloat.pi / 4.0
            context.move(to: CGPoint(x: center.x + cos(angle) * 7.0, y: center.y + sin(angle) * 7.0))
            context.addLine(to: CGPoint(x: center.x + cos(angle) * 10.0, y: center.y + sin(angle) * 10.0))
        }
        context.strokePath()
    })
}

final class FocusCrosshairsView: UIView {
    private let indicatorView: UIView
    private let crosshairsView: UIImageView
    private let exposureClipView: UIView
    private let exposureIndicatorView: UIView
    private let exposureIconView: UIImageView
    private let exposureTopLine: UIView
    private let exposureBottomLine: UIView

    private(set) var exposureValue: CGFloat = 0.0
    private var deactivateTimer: SwiftSignalKit.Timer?
    private var stopTimer: SwiftSignalKit.Timer?
    private var hideTimer: SwiftSignalKit.Timer?

    var exposureChangeEnded: (() -> Void)?

    override init(frame: CGRect) {
        self.indicatorView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: indicatorSide, height: indicatorSide)))
        self.indicatorView.isHidden = true

        self.crosshairsView = UIImageView(frame: CGRect(x: crosshairsInset, y: crosshairsInset, width: crosshairsSide, height: crosshairsSide))
        self.crosshairsView.image = generateCrosshairsImage()

        self.exposureClipView = UIView()
        self.exposureClipView.clipsToBounds = true

        self.exposureIndicatorView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: exposureIconSide, height: exposureTrackHeight))

        self.exposureIconView = UIImageView(frame: CGRect(x: -1.0, y: (exposureTrackHeight - exposureIconSide) / 2.0, width: exposureIconSide, height: exposureIconSide))
        self.exposureIconView.image = generateExposureIconImage()

        self.exposureTopLine = UIView(frame: CGRect(x: 11.0, y: (exposureTrackHeight - exposureIconSide) / 2.0 - 3.0 - exposureTrackHeight, width: 1.0, height: exposureTrackHeight))
        self.exposureTopLine.backgroundColor = focusAccentColor
        self.exposureTopLine.alpha = 0.0

        self.exposureBottomLine = UIView(frame: CGRect(x: 11.0, y: (exposureTrackHeight + exposureIconSide) / 2.0 + 3.0, width: 1.0, height: exposureTrackHeight))
        self.exposureBottomLine.backgroundColor = focusAccentColor
        self.exposureBottomLine.alpha = 0.0

        super.init(frame: frame)

        self.isUserInteractionEnabled = false

        self.addSubview(self.indicatorView)
        self.indicatorView.addSubview(self.crosshairsView)
        self.indicatorView.addSubview(self.exposureClipView)
        self.exposureClipView.addSubview(self.exposureIndicatorView)
        self.exposureIndicatorView.addSubview(self.exposureIconView)
        self.exposureIndicatorView.addSubview(self.exposureTopLine)
        self.exposureIndicatorView.addSubview(self.exposureBottomLine)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.deactivateTimer?.invalidate()
        self.stopTimer?.invalidate()
        self.hideTimer?.invalidate()
    }

    private func invalidateTimers() {
        self.deactivateTimer?.invalidate()
        self.deactivateTimer = nil
        self.stopTimer?.invalidate()
        self.stopTimer = nil
        self.hideTimer?.invalidate()
        self.hideTimer = nil
    }

    func canAdjustExposure(at point: CGPoint) -> Bool {
        return !self.indicatorView.isHidden && self.indicatorView.alpha > 0.0 && self.indicatorView.frame.contains(point)
    }

    func showFocus(at point: CGPoint) {
        self.invalidateTimers()

        self.indicatorView.layer.removeAllAnimations()
        self.crosshairsView.layer.removeAllAnimations()
        self.indicatorView.frame = CGRect(x: floor(point.x - indicatorSide / 2.0), y: floor(point.y - indicatorSide / 2.0), width: indicatorSide, height: indicatorSide)
        self.indicatorView.alpha = 1.0
        self.indicatorView.isHidden = false

        let defaultFrame = CGRect(x: crosshairsInset + crosshairsSide + 5.0, y: crosshairsInset + (crosshairsSide - exposureTrackHeight) / 2.0, width: exposureIconSide, height: exposureTrackHeight)
        if self.indicatorView.frame.maxX > self.bounds.width {
            self.exposureClipView.frame = CGRect(x: 15.0, y: defaultFrame.minY, width: defaultFrame.width, height: defaultFrame.height)
        } else {
            self.exposureClipView.frame = defaultFrame
        }

        self.exposureValue = 0.0
        self.setExposureSliderPosition(0.0)
        self.setExposureTrackHidden(true, animated: false)

        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 2.0 as NSNumber
        scaleAnimation.toValue = 1.0 as NSNumber
        scaleAnimation.duration = 0.15
        self.indicatorView.layer.add(scaleAnimation, forKey: "scale")

        let blinkAnimation = CAKeyframeAnimation(keyPath: "opacity")
        blinkAnimation.duration = 2.0
        blinkAnimation.repeatCount = .infinity
        blinkAnimation.keyTimes = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
        blinkAnimation.values = [0.6, 1.0, 0.6, 1.0, 0.6, 1.0, 0.6, 1.0, 0.6, 1.0, 0.6]
        self.crosshairsView.layer.add(blinkAnimation, forKey: "opacity")

        let stopTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: false, completion: { [weak self] in
            self?.stopFocusAnimation()
        }, queue: Queue.mainQueue())
        self.stopTimer = stopTimer
        stopTimer.start()
    }

    private func stopFocusAnimation() {
        self.stopTimer = nil
        self.crosshairsView.layer.removeAnimation(forKey: "opacity")
        UIView.animate(withDuration: 0.2, delay: 0.9, options: [.allowUserInteraction], animations: {
            self.indicatorView.alpha = 0.5
        })
        self.scheduleHide()
    }

    private func scheduleHide() {
        self.hideTimer?.invalidate()
        let hideTimer = SwiftSignalKit.Timer(timeout: 4.0, repeat: false, completion: { [weak self] in
            guard let self else {
                return
            }
            self.hideTimer = nil
            UIView.animate(withDuration: 0.3, animations: {
                self.indicatorView.alpha = 0.0
            }, completion: { _ in
                if self.indicatorView.alpha == 0.0 {
                    self.indicatorView.isHidden = true
                }
            })
        }, queue: Queue.mainQueue())
        self.hideTimer = hideTimer
        hideTimer.start()
    }

    func beginExposureChange() {
        self.deactivateTimer?.invalidate()
        self.deactivateTimer = nil
        self.hideTimer?.invalidate()
        self.hideTimer = nil
    }

    func updateExposure(value: CGFloat) {
        self.exposureValue = value
        self.setExposureSliderPosition(value)
        self.setExposureTrackHidden(false, animated: false)
        self.indicatorView.layer.removeAllAnimations()
        self.indicatorView.alpha = 1.0
    }

    func endExposureChange() {
        self.deactivateTimer?.invalidate()
        let deactivateTimer = SwiftSignalKit.Timer(timeout: 2.0, repeat: false, completion: { [weak self] in
            guard let self else {
                return
            }
            self.deactivateTimer = nil
            UIView.animate(withDuration: 0.3, animations: {
                self.indicatorView.alpha = 0.5
            })
            self.setExposureTrackHidden(true, animated: true)
            self.exposureChangeEnded?()
            self.scheduleHide()
        }, queue: Queue.mainQueue())
        self.deactivateTimer = deactivateTimer
        deactivateTimer.start()
    }

    func reset() {
        let wasAdjusting = self.deactivateTimer != nil
        self.invalidateTimers()
        self.crosshairsView.layer.removeAllAnimations()
        self.indicatorView.layer.removeAllAnimations()
        self.indicatorView.isHidden = true
        if wasAdjusting {
            self.exposureChangeEnded?()
        }
    }

    private func setExposureSliderPosition(_ value: CGFloat) {
        self.exposureIndicatorView.frame = CGRect(x: self.exposureIndicatorView.frame.minX, y: chatCameraExposureSliderOffset(value: value), width: self.exposureIndicatorView.frame.width, height: self.exposureIndicatorView.frame.height)
    }

    private func setExposureTrackHidden(_ hidden: Bool, animated: Bool) {
        let alpha: CGFloat = hidden ? 0.0 : 1.0
        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                self.exposureTopLine.alpha = alpha
                self.exposureBottomLine.alpha = alpha
            })
        } else {
            self.exposureTopLine.alpha = alpha
            self.exposureBottomLine.alpha = alpha
        }
    }
}
