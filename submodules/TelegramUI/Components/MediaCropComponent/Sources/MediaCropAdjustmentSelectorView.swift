import Foundation
import UIKit
import Display
import MediaEditor

public enum MediaCropAdjustment: CaseIterable {
    case straighten
    case vertical
    case horizontal
}

public let mediaCropAdjustmentSelectorHeight: CGFloat = 50.0

private let mediaCropAdjustmentButtonDiameter: CGFloat = 50.0
private let mediaCropAdjustmentButtonSpacing: CGFloat = 71.0
private let mediaCropAdjustmentRingWidth: CGFloat = 5.0 / 3.0
private let mediaCropAdjustmentAccentColor = UIColor(rgb: 0xffcc00)
private let mediaCropAdjustmentRingColor = UIColor(white: 1.0, alpha: 0.35)
private let mediaCropAdjustmentFillColor = UIColor(white: 1.0, alpha: 0.08)
private let mediaCropAdjustmentDisabledAlpha: CGFloat = 0.35
private let mediaCropAdjustmentIconSize = CGSize(width: 24.0, height: 24.0)

public func mediaCropAdjustmentLimit(_ adjustment: MediaCropAdjustment) -> CGFloat {
    switch adjustment {
    case .straighten:
        return mediaCropMaximumWheelAngle
    case .vertical, .horizontal:
        return mediaEditorCropMaximumPerspectiveAngle
    }
}

public func mediaCropAdjustmentLabel(degrees: CGFloat) -> String? {
    let rounded = Int(degrees.rounded())
    if rounded == 0 {
        return nil
    }
    return "\(rounded)"
}

public func mediaCropAdjustmentRingProgress(degrees: CGFloat, limit: CGFloat) -> CGFloat {
    guard limit > 0.0 else {
        return 0.0
    }
    return min(1.0, abs(degrees) / limit)
}

private func mediaCropAdjustmentIcon(_ adjustment: MediaCropAdjustment) -> UIImage {
    let size = mediaCropAdjustmentIconSize
    let format = UIGraphicsImageRendererFormat()
    format.opaque = false
    let image = UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
        let context = rendererContext.cgContext
        context.setFillColor(UIColor.white.cgColor)
        let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        let lineThickness: CGFloat = 1.0
        let lineLength: CGFloat = 21.0
        switch adjustment {
        case .straighten:
            let diameter: CGFloat = 15.0
            context.fillEllipse(in: CGRect(x: center.x - diameter / 2.0, y: center.y - diameter / 2.0, width: diameter, height: diameter))
            context.setBlendMode(.clear)
            context.fill(CGRect(x: 0.0, y: center.y - lineThickness / 2.0, width: size.width, height: lineThickness))
            context.setBlendMode(.normal)
            context.fill(CGRect(x: center.x - lineLength / 2.0, y: center.y - lineThickness / 2.0, width: (lineLength - diameter) / 2.0, height: lineThickness))
            context.fill(CGRect(x: center.x + diameter / 2.0, y: center.y - lineThickness / 2.0, width: (lineLength - diameter) / 2.0, height: lineThickness))
        case .vertical, .horizontal:
            if adjustment == .horizontal {
                context.translateBy(x: center.x, y: center.y)
                context.rotate(by: -.pi / 2.0)
                context.translateBy(x: -center.x, y: -center.y)
            }
            let topWidth: CGFloat = 10.0
            let bottomWidth: CGFloat = 17.0
            let height: CGFloat = 13.3
            let path = UIBezierPath()
            path.move(to: CGPoint(x: center.x - topWidth / 2.0, y: center.y - height / 2.0))
            path.addLine(to: CGPoint(x: center.x + topWidth / 2.0, y: center.y - height / 2.0))
            path.addLine(to: CGPoint(x: center.x + bottomWidth / 2.0, y: center.y + height / 2.0))
            path.addLine(to: CGPoint(x: center.x - bottomWidth / 2.0, y: center.y + height / 2.0))
            path.close()
            path.lineJoinStyle = .round
            path.lineWidth = 1.0
            UIColor.white.setStroke()
            path.fill()
            path.stroke()
            context.setBlendMode(.clear)
            context.fill(CGRect(x: center.x - lineThickness / 2.0, y: 0.0, width: lineThickness, height: size.height))
            context.setBlendMode(.normal)
            context.fill(CGRect(x: center.x - lineThickness / 2.0, y: center.y - lineLength / 2.0, width: lineThickness, height: lineLength))
            context.setBlendMode(.clear)
            context.fill(CGRect(x: center.x - lineThickness / 2.0, y: center.y - height / 2.0, width: lineThickness, height: height))
        }
    }
    return image.withRenderingMode(.alwaysTemplate)
}

private final class MediaCropAdjustmentButton: UIControl {
    let adjustment: MediaCropAdjustment
    private let ringLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let iconView: UIImageView
    private let valueLabel = UILabel()

    init(adjustment: MediaCropAdjustment) {
        self.adjustment = adjustment
        self.iconView = UIImageView(image: mediaCropAdjustmentIcon(adjustment))

        super.init(frame: CGRect(origin: .zero, size: CGSize(width: mediaCropAdjustmentButtonDiameter, height: mediaCropAdjustmentButtonDiameter)))

        let bounds = self.bounds
        let ringRect = bounds.insetBy(dx: mediaCropAdjustmentRingWidth / 2.0, dy: mediaCropAdjustmentRingWidth / 2.0)
        self.ringLayer.path = UIBezierPath(ovalIn: ringRect).cgPath
        self.ringLayer.lineWidth = mediaCropAdjustmentRingWidth
        self.ringLayer.fillColor = mediaCropAdjustmentFillColor.cgColor
        self.ringLayer.strokeColor = mediaCropAdjustmentRingColor.cgColor
        self.layer.addSublayer(self.ringLayer)

        self.progressLayer.lineWidth = mediaCropAdjustmentRingWidth
        self.progressLayer.fillColor = UIColor.clear.cgColor
        self.progressLayer.strokeColor = mediaCropAdjustmentAccentColor.cgColor
        self.progressLayer.lineCap = .butt
        self.progressLayer.strokeEnd = 0.0
        self.layer.addSublayer(self.progressLayer)

        self.iconView.tintColor = .white
        self.iconView.frame = CGRect(origin: CGPoint(x: (bounds.width - mediaCropAdjustmentIconSize.width) / 2.0, y: (bounds.height - mediaCropAdjustmentIconSize.height) / 2.0), size: mediaCropAdjustmentIconSize)
        self.addSubview(self.iconView)

        self.valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 15.0, weight: .regular)
        self.valueLabel.textColor = mediaCropAdjustmentAccentColor
        self.valueLabel.textAlignment = .center
        self.valueLabel.frame = bounds
        self.valueLabel.isHidden = true
        self.addSubview(self.valueLabel)

        for view in [self.iconView, self.valueLabel] as [UIView] {
            view.isUserInteractionEnabled = false
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(degrees: CGFloat, isEnabled: Bool) {
        let limit = mediaCropAdjustmentLimit(self.adjustment)
        let label = isEnabled ? mediaCropAdjustmentLabel(degrees: degrees) : nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let label {
            self.valueLabel.text = label
            self.valueLabel.isHidden = false
            self.iconView.isHidden = true
            let center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
            let radius = (mediaCropAdjustmentButtonDiameter - mediaCropAdjustmentRingWidth) / 2.0
            let clockwise = degrees >= 0.0
            self.progressLayer.path = UIBezierPath(arcCenter: center, radius: radius, startAngle: -.pi / 2.0, endAngle: clockwise ? 1.5 * .pi : -2.5 * .pi, clockwise: clockwise).cgPath
            self.progressLayer.strokeEnd = mediaCropAdjustmentRingProgress(degrees: degrees, limit: limit)
            self.progressLayer.isHidden = false
            self.ringLayer.strokeColor = mediaCropAdjustmentAccentColor.withAlphaComponent(0.3).cgColor
            self.iconView.alpha = 1.0
            self.ringLayer.opacity = 1.0
        } else {
            self.valueLabel.isHidden = true
            self.iconView.isHidden = false
            self.progressLayer.isHidden = true
            self.ringLayer.strokeColor = mediaCropAdjustmentRingColor.cgColor
            self.iconView.alpha = isEnabled ? 1.0 : mediaCropAdjustmentDisabledAlpha
            self.ringLayer.opacity = isEnabled ? 1.0 : Float(mediaCropAdjustmentDisabledAlpha)
        }
        CATransaction.commit()
    }
}

public final class MediaCropAdjustmentSelectorView: UIView {
    public private(set) var selected: MediaCropAdjustment = .straighten
    public var selectionChanged: ((MediaCropAdjustment) -> Void)?
    public var selectedTapped: ((MediaCropAdjustment) -> Void)?
    public var layoutAxis: MediaCropDialAxis = .horizontal {
        didSet {
            if self.layoutAxis != oldValue {
                self.setNeedsLayout()
            }
        }
    }

    private let buttons: [MediaCropAdjustmentButton]

    override public init(frame: CGRect) {
        self.buttons = MediaCropAdjustment.allCases.map { MediaCropAdjustmentButton(adjustment: $0) }

        super.init(frame: frame)

        for button in self.buttons {
            button.addTarget(self, action: #selector(self.buttonPressed(_:)), for: .touchUpInside)
            self.addSubview(button)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func buttonPressed(_ button: MediaCropAdjustmentButton) {
        if button.adjustment == self.selected {
            self.selectedTapped?(button.adjustment)
        } else {
            self.setSelected(button.adjustment, animated: true)
            self.selectionChanged?(button.adjustment)
        }
    }

    public func setSelected(_ adjustment: MediaCropAdjustment, animated: Bool) {
        self.selected = adjustment
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                self.layoutButtons()
            })
        } else {
            self.layoutButtons()
        }
    }

    public func setValues(_ values: [MediaCropAdjustment: CGFloat], disabled: Set<MediaCropAdjustment>) {
        for button in self.buttons {
            button.update(degrees: values[button.adjustment] ?? 0.0, isEnabled: !disabled.contains(button.adjustment))
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        self.layoutButtons()
    }

    private func layoutButtons() {
        let selectedIndex = MediaCropAdjustment.allCases.firstIndex(of: self.selected) ?? 0
        for (index, button) in self.buttons.enumerated() {
            let offset = CGFloat(index - selectedIndex) * mediaCropAdjustmentButtonSpacing
            switch self.layoutAxis {
            case .horizontal:
                button.center = CGPoint(x: self.bounds.midX + offset, y: self.bounds.midY)
            case let .vertical(clockwise):
                button.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY + (clockwise ? offset : -offset))
            }
        }
    }

    override public func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        for button in self.buttons {
            if button.frame.contains(point) {
                return true
            }
        }
        return false
    }
}
