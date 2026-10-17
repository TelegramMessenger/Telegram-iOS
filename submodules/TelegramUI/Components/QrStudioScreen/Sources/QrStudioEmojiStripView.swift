import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TextFormat
import EmojiTextAttachmentView
import GlassBackgroundComponent

final class QrStudioEmojiStripView: UIView {
    private final class Item {
        let emoji: QrStudioEmojiItem
        let layer: InlineStickerItemLayer

        init(emoji: QrStudioEmojiItem, layer: InlineStickerItemLayer) {
            self.emoji = emoji
            self.layer = layer
        }
    }

    static let height: CGFloat = 44.0
    private static let itemSide: CGFloat = 30.0
    private static let spacing: CGFloat = 6.0
    private static let inset: CGFloat = 10.0

    var tap: ((QrStudioEmojiItem) -> Void)?

    private let glass = GlassBackgroundView()
    private let contentView = UIView()
    private var items: [Int64: Item] = [:]
    private var order: [Int64] = []
    private(set) var isShown = false
    private var dynamicColor: UIColor = .white

    static func width(count: Int) -> CGFloat {
        guard count > 0 else {
            return QrStudioEmojiStripView.height
        }
        return QrStudioEmojiStripView.inset * 2.0 + CGFloat(count) * QrStudioEmojiStripView.itemSide + CGFloat(count - 1) * QrStudioEmojiStripView.spacing
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.isHidden = true
        self.addSubview(self.glass)
        self.contentView.isUserInteractionEnabled = false
        self.addSubview(self.contentView)
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:))))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard case .ended = recognizer.state, self.isShown else {
            return
        }
        let location = recognizer.location(in: self.contentView)
        var closest: (Item, CGFloat)?
        for id in self.order {
            guard let item = self.items[id] else {
                continue
            }
            let distance = abs(item.layer.position.x - location.x)
            if closest == nil || distance < closest!.1 {
                closest = (item, distance)
            }
        }
        if let closest, closest.1 < QrStudioEmojiStripView.itemSide * 0.5 + QrStudioEmojiStripView.spacing {
            self.tap?(closest.0.emoji)
        }
    }

    func update(context: AccountContext, emoji: [QrStudioEmojiItem], isDark: Bool, glassTint: GlassBackgroundView.TintColor, size: CGSize, transition: ComponentTransition) {
        let foreground = isDark ? UIColor(white: 0.96, alpha: 1.0) : UIColor(white: 0.1, alpha: 1.0)
        self.dynamicColor = foreground

        let bounds = CGRect(origin: CGPoint(), size: size)
        transition.setFrame(view: self.glass, frame: bounds)
        self.glass.nativeBlurRadius = QrStudioGlass.blurRadius(glassTint)
        self.glass.update(size: size, cornerRadius: size.height * 0.5, isDark: QrStudioGlass.glassIsDark(isDark, tint: glassTint), tintColor: glassTint, transition: transition)
        transition.setFrame(view: self.contentView, frame: bounds)

        let ids = emoji.map { $0.id }
        let side = QrStudioEmojiStripView.itemSide
        var x = (size.width - QrStudioEmojiStripView.width(count: emoji.count)) * 0.5 + QrStudioEmojiStripView.inset
        for item in emoji {
            let center = CGPoint(x: x + side * 0.5, y: size.height * 0.5)
            x += side + QrStudioEmojiStripView.spacing
            if let current = self.items[item.id] {
                current.layer.dynamicColor = item.isTemplate ? foreground : nil
                transition.setPosition(layer: current.layer, position: center)
            } else {
                let layer = InlineStickerItemLayer(
                    context: context,
                    userLocation: .other,
                    attemptSynchronousLoad: true,
                    emoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: item.file.fileId.id, file: item.file),
                    file: item.file,
                    cache: context.animationCache,
                    renderer: context.animationRenderer,
                    placeholderColor: foreground.withAlphaComponent(0.1),
                    pointSize: CGSize(width: side, height: side),
                    dynamicColor: item.isTemplate ? foreground : nil
                )
                layer.bounds = CGRect(origin: CGPoint(), size: CGSize(width: side, height: side))
                layer.position = center
                layer.isVisibleForAnimations = self.isShown
                self.contentView.layer.addSublayer(layer)
                self.items[item.id] = Item(emoji: item, layer: layer)
                if !transition.animation.isImmediate && self.isShown {
                    layer.animateScale(from: 0.01, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                    layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
        }
        for (id, item) in self.items where !ids.contains(id) {
            self.items.removeValue(forKey: id)
            let layer = item.layer
            if !transition.animation.isImmediate && self.isShown {
                layer.animateScale(from: 1.0, to: 0.01, duration: 0.25, removeOnCompletion: false)
                layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak layer] _ in
                    layer?.removeFromSuperlayer()
                })
            } else {
                layer.removeFromSuperlayer()
            }
        }
        self.order = ids
    }

    private func removeVisibilityAnimations() {
        for key in ["opacity", "transform"] {
            self.layer.removeAnimation(forKey: key)
        }
        self.layer.removeAnimation(forKey: "filters.gaussianBlur.inputRadius")
        self.layer.filters = nil
        self.layer.transform = CATransform3DIdentity
    }

    func setShown(_ isShown: Bool, animated: Bool) {
        guard self.isShown != isShown else {
            return
        }
        self.isShown = isShown
        for (_, item) in self.items {
            item.layer.isVisibleForAnimations = isShown
        }
        self.removeVisibilityAnimations()
        guard animated else {
            self.isHidden = !isShown
            return
        }
        if isShown {
            self.isHidden = false
            self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
            let spring = QrStudioSheetMotion.riseOpen
            let stiffness = pow(2.0 * Double.pi / spring.duration, 2.0)
            let lift = CASpringAnimation(keyPath: "transform")
            lift.fromValue = NSValue(caTransform3D: CATransform3DMakeTranslation(0.0, 32.0, 0.0))
            lift.toValue = NSValue(caTransform3D: CATransform3DIdentity)
            lift.mass = 1.0
            lift.stiffness = stiffness
            lift.damping = 2.0 * (1.0 - spring.bounce) * stiffness.squareRoot()
            lift.duration = lift.settlingDuration
            self.layer.add(lift, forKey: "transform")
            ComponentTransition.easeInOut(duration: 0.3).animateBlur(layer: self.layer, fromRadius: 10.0, toRadius: 0.0)
        } else {
            self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] _ in
                guard let self, !self.isShown else {
                    return
                }
                self.isHidden = true
                self.removeVisibilityAnimations()
            })
            self.layer.animate(from: NSValue(caTransform3D: CATransform3DIdentity), to: NSValue(caTransform3D: CATransform3DMakeTranslation(0.0, 16.0, 0.0)), keyPath: "transform", timingFunction: CAMediaTimingFunctionName.easeIn.rawValue, duration: 0.2, removeOnCompletion: false)
            ComponentTransition.easeInOut(duration: 0.2).animateBlur(layer: self.layer, fromRadius: 0.0, toRadius: 10.0, removeOnCompletion: false)
        }
    }
}
