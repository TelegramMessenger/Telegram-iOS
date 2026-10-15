import Foundation
import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent

enum QrStudioGlass {
    static func tint(_ backdrop: QrStudioBackdrop) -> GlassBackgroundView.TintColor {
        if #available(iOS 27.0, *) {
        } else if !QrStudioGlass.isEmoji(backdrop) {
            return GlassBackgroundView.TintColor(kind: .clear)
        }
        return GlassBackgroundView.TintColor(kind: .custom(style: .default, color: .clear))
    }

    static func glassIsDark(_ isDark: Bool, tint: GlassBackgroundView.TintColor) -> Bool {
        if tint.kind == .clear {
            return false
        }
        return isDark
    }

    private static func isEmoji(_ backdrop: QrStudioBackdrop) -> Bool {
        if case .emoji = backdrop {
            return true
        }
        return false
    }
}

func qrStudioCrossfadeGlass(_ view: UIView, duration: Double = 0.45) {
    guard view.window != nil, view.bounds.width > 0.0, let snapshot = view.snapshotView(afterScreenUpdates: false) else {
        return
    }
    snapshot.isUserInteractionEnabled = false
    snapshot.frame = view.frame
    view.superview?.insertSubview(snapshot, aboveSubview: view)
    UIView.animate(withDuration: duration, delay: 0.0, options: [.curveEaseInOut], animations: {
        snapshot.alpha = 0.0
    }, completion: { _ in
        snapshot.removeFromSuperview()
    })
}

final class QrStudioGlassButtonView: UIView {
    let glass = GlassContextExtractableContainer()
    private let iconView = UIImageView()
    private let touchView = UIView()
    private var icon: String?
    private var isDark: Bool?

    var action: ((UIView) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.glass.morphsIntoContextMenu = true
        self.addSubview(self.glass)

        self.iconView.contentMode = .center
        self.glass.contentView.addSubview(self.iconView)
        self.glass.contentView.addSubview(self.touchView)

        self.touchView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        if result === self {
            return self.touchView
        }
        return result
    }

    @objc private func tapped() {
        self.action?(self.glass)
    }

    func update(size: CGSize, isDark: Bool, glassTint: GlassBackgroundView.TintColor, icon: String, transition: ComponentTransition) {
        if self.icon != icon || self.isDark != isDark {
            if self.isDark != nil && self.isDark != isDark && !transition.animation.isImmediate {
                qrStudioCrossfadeGlass(self.glass)
            }
            self.icon = icon
            self.isDark = isDark
            let color = isDark ? UIColor(white: 0.96, alpha: 1.0) : UIColor(white: 0.1, alpha: 1.0)
            self.iconView.image = generateTintedImage(image: UIImage(bundleImageName: icon), color: color)
        }
        transition.setFrame(view: self.glass, frame: CGRect(origin: CGPoint(), size: size))
        self.glass.update(size: size, cornerRadius: size.height * 0.5, isDark: QrStudioGlass.glassIsDark(isDark, tint: glassTint), tintColor: glassTint, isInteractive: true, transition: transition)
        transition.setFrame(view: self.iconView, frame: CGRect(origin: CGPoint(), size: size))
        self.touchView.frame = CGRect(origin: CGPoint(), size: size)
    }
}
