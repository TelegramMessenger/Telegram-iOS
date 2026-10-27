import UIKit

final class DemoScrubberView: UIView {
    private let thumb = UIView()
    private let label = UILabel()
    private let pan = UIPanGestureRecognizer()
    private var fraction: CGFloat = 0.0

    private(set) var isDragging = false
    var onChange: ((CGFloat) -> Void)?

    private let thumbSize = CGSize(width: 44.0, height: 36.0)
    private let trackInsets = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 8.0, right: 0.0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.thumb.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        self.thumb.layer.cornerRadius = 10.0
        self.addSubview(self.thumb)
        self.label.font = UIFont.systemFont(ofSize: 13.0, weight: .semibold)
        self.label.textColor = .white
        self.label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        self.label.layer.cornerRadius = 10.0
        self.label.layer.masksToBounds = true
        self.label.textAlignment = .center
        self.addSubview(self.label)
        self.pan.addTarget(self, action: #selector(self.panned(_:)))
        self.addGestureRecognizer(self.pan)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var dateText: String? {
        didSet {
            self.label.text = self.dateText.map { "  \($0)  " }
            self.setNeedsLayout()
        }
    }

    func setFraction(_ fraction: CGFloat) {
        if self.isDragging {
            return
        }
        self.fraction = min(max(0.0, fraction), 1.0)
        self.setNeedsLayout()
    }

    private var trackRange: (CGFloat, CGFloat) {
        let top = self.trackInsets.top + self.thumbSize.height / 2.0
        let bottom = self.bounds.height - self.trackInsets.bottom - self.thumbSize.height / 2.0
        return (top, max(top, bottom))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let (top, bottom) = self.trackRange
        let centerY = top + (bottom - top) * self.fraction
        self.thumb.frame = CGRect(x: self.bounds.width - self.thumbSize.width, y: centerY - self.thumbSize.height / 2.0, width: self.thumbSize.width, height: self.thumbSize.height)
        let labelSize = self.label.sizeThatFits(CGSize(width: 200.0, height: self.thumbSize.height))
        self.label.frame = CGRect(x: self.thumb.frame.minX - labelSize.width - 6.0, y: self.thumb.frame.minY, width: labelSize.width, height: self.thumbSize.height)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.thumb.frame.insetBy(dx: -12.0, dy: -12.0).contains(point)
    }

    @objc private func panned(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            self.isDragging = true
            fallthrough
        case .changed:
            let (top, bottom) = self.trackRange
            let y = recognizer.location(in: self).y
            let fraction = bottom > top ? min(max(0.0, (y - top) / (bottom - top)), 1.0) : 0.0
            self.fraction = fraction
            self.setNeedsLayout()
            self.layoutIfNeeded()
            self.onChange?(fraction)
        case .ended, .cancelled, .failed:
            self.isDragging = false
        default:
            break
        }
    }
}
