import Foundation
import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent

enum QrStudioGlass {
    static func tint(_ backdrop: QrStudioBackdrop) -> GlassBackgroundView.TintColor {
        if #available(iOS 27.0, *) {
        } else {
            return GlassBackgroundView.TintColor(kind: .custom(style: .clear, color: .clear))
        }
        return GlassBackgroundView.TintColor(kind: .custom(style: .default, color: .clear))
    }

    static func isClear(_ tint: GlassBackgroundView.TintColor) -> Bool {
        if case let .custom(style, _) = tint.kind, style == .clear {
            return true
        }
        return false
    }

    static func blurRadius(_ tint: GlassBackgroundView.TintColor) -> CGFloat? {
        return QrStudioGlass.isClear(tint) ? 8.0 : nil
    }

    static func glassIsDark(_ isDark: Bool, tint: GlassBackgroundView.TintColor) -> Bool {
        return isDark
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
    private let titleLabel = UILabel()
    private let touchView = UIView()
    private var icon: String?
    private var title: String?
    private var isDark: Bool?

    var action: ((UIView) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.glass.morphsIntoContextMenu = true
        self.addSubview(self.glass)

        self.iconView.contentMode = .center
        self.glass.contentView.addSubview(self.iconView)
        self.titleLabel.textAlignment = .center
        self.glass.contentView.addSubview(self.titleLabel)
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

    static let titleFont = Font.regular(17.0)
    static let titleInset: CGFloat = 12.0

    static func width(title: String, height: CGFloat) -> CGFloat {
        let textWidth = ceil((title as NSString).size(withAttributes: [.font: QrStudioGlassButtonView.titleFont]).width)
        return max(height, textWidth + QrStudioGlassButtonView.titleInset * 2.0)
    }

    func update(size: CGSize, isDark: Bool, glassTint: GlassBackgroundView.TintColor, icon: String? = nil, title: String? = nil, transition: ComponentTransition) {
        if self.icon != icon || self.title != title || self.isDark != isDark {
            if self.isDark != nil && self.isDark != isDark && !transition.animation.isImmediate {
                qrStudioCrossfadeGlass(self.glass)
            }
            self.icon = icon
            self.title = title
            self.isDark = isDark
            let color = isDark ? UIColor(white: 0.96, alpha: 1.0) : UIColor(white: 0.1, alpha: 1.0)
            self.iconView.image = icon.flatMap { name -> UIImage? in
                if name.hasPrefix("sf:") {
                    return UIImage(systemName: String(name.dropFirst(3)), withConfiguration: UIImage.SymbolConfiguration(pointSize: 17.0, weight: .semibold))?.withTintColor(color, renderingMode: .alwaysOriginal)
                }
                return generateTintedImage(image: UIImage(bundleImageName: name), color: color)
            }
            self.titleLabel.attributedText = title.flatMap { NSAttributedString(string: $0, font: QrStudioGlassButtonView.titleFont, textColor: color) }
        }
        transition.setFrame(view: self.glass, frame: CGRect(origin: CGPoint(), size: size))
        self.glass.nativeBlurRadius = QrStudioGlass.blurRadius(glassTint)
        self.glass.update(size: size, cornerRadius: size.height * 0.5, isDark: QrStudioGlass.glassIsDark(isDark, tint: glassTint), tintColor: glassTint, isInteractive: true, transition: transition)
        transition.setFrame(view: self.iconView, frame: CGRect(origin: CGPoint(), size: size))
        transition.setFrame(view: self.titleLabel, frame: CGRect(origin: CGPoint(), size: size))
        self.touchView.frame = CGRect(origin: CGPoint(), size: size)
    }
}
