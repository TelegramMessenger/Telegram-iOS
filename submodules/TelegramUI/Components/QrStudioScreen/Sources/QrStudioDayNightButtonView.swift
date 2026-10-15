import Foundation
import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent
import AnimationUI

private let qrStudioSunLayers: [String] = [
    "Sunny.Path 14.Path.Stroke 1",
    "Sunny.Path 15.Path.Stroke 1",
    "Path.Path.Stroke 1",
    "Sunny.Path 39.Path.Stroke 1",
    "Sunny.Path 24.Path.Stroke 1",
    "Sunny.Path 25.Path.Stroke 1",
    "Sunny.Path 18.Path.Stroke 1",
    "Sunny.Path 41.Path.Stroke 1",
    "Sunny.Path 43.Path.Stroke 1",
    "Path 10.Path.Fill 1",
    "Path 11.Path.Fill 1"
]

private func qrStudioSunColors(_ color: UIColor) -> [String: UIColor] {
    var colors: [String: UIColor] = [:]
    for name in qrStudioSunLayers {
        colors[name] = color
    }
    return colors
}

final class QrStudioDayNightButtonView: UIView {
    private let glass = GlassBackgroundView()
    private let animationNode: AnimationNode
    private var isNight: Bool?
    private var isDarkGlass: Bool?
    private var iconColor: UIColor?
    private var colorAnimator: DisplayLinkAnimator?

    var action: (() -> Void)?

    override init(frame: CGRect) {
        self.animationNode = AnimationNode(animation: "anim_sun", colors: qrStudioSunColors(.black), scale: 1.0)

        super.init(frame: frame)

        self.addSubview(self.glass)
        self.animationNode.isUserInteractionEnabled = false
        self.addSubview(self.animationNode.view)

        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func tapped() {
        self.action?()
    }

    private static func iconColor(isDarkGlass: Bool) -> UIColor {
        return isDarkGlass ? UIColor(white: 0.96, alpha: 1.0) : UIColor(white: 0.1, alpha: 1.0)
    }

    func update(size: CGSize, isNight: Bool, isDarkGlass: Bool, glassTint: GlassBackgroundView.TintColor, transition: ComponentTransition) {
        if let previous = self.isDarkGlass, previous != isDarkGlass, !transition.animation.isImmediate {
            qrStudioCrossfadeGlass(self.glass)
        }
        let color = QrStudioDayNightButtonView.iconColor(isDarkGlass: isDarkGlass)
        let previousColor = self.iconColor ?? color
        let animatesColor = self.iconColor != nil && previousColor != color && !transition.animation.isImmediate
        self.iconColor = color
        let startColor = animatesColor ? previousColor : color
        if let previous = self.isNight, previous != isNight {
            self.animationNode.setAnimation(name: previous ? "anim_sun_reverse" : "anim_sun", colors: qrStudioSunColors(startColor))
            self.animationNode.playOnce()
        } else if self.isNight == nil {
            self.animationNode.setAnimation(name: isNight ? "anim_sun_reverse" : "anim_sun", colors: qrStudioSunColors(color))
        } else if self.isDarkGlass != isDarkGlass && !animatesColor {
            self.animationNode.setColors(colors: qrStudioSunColors(color))
        }
        if animatesColor {
            self.colorAnimator?.invalidate()
            self.colorAnimator = DisplayLinkAnimator(duration: 0.35, from: 0.0, to: 1.0, update: { [weak self] value in
                self?.animationNode.setColors(colors: qrStudioSunColors(previousColor.interpolateTo(color, fraction: value) ?? color))
            }, completion: { [weak self] in
                self?.animationNode.setColors(colors: qrStudioSunColors(color))
                self?.colorAnimator?.invalidate()
                self?.colorAnimator = nil
            })
        }
        self.isNight = isNight
        self.isDarkGlass = isDarkGlass

        transition.setFrame(view: self.glass, frame: CGRect(origin: CGPoint(), size: size))
        self.glass.update(size: size, cornerRadius: size.height * 0.5, isDark: QrStudioGlass.glassIsDark(isDarkGlass, tint: glassTint), tintColor: glassTint, isInteractive: false, transition: transition)
        let iconFrame = CGRect(origin: CGPoint(), size: size).insetBy(dx: 5.0, dy: 5.0)
        self.animationNode.frame = iconFrame
    }
}
