import UIKit

/// Demo of `PhysicsScrollView` — a scroll view driven by the reverse-engineered `ScrollPhysics`
/// (no `UIScrollView`). A tall column of rows showcases drag, flick deceleration, edge bounce, and
/// rubber-band; a live HUD shows the offset / velocity / phase the physics produces.
final class PhysicsScrollDemoViewController: UIViewController {
    private let scrollView = PhysicsScrollView()
    private let caption = UILabel()
    private let hud = UILabel()
    private let modeControl = UISegmentedControl(items: ["Keyframe", "Stepped"])
    private var rows: [UIView] = []
    private let rowHeight: CGFloat = 64
    private let rowCount = 60

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Physics Scroll"

        caption.text = "Custom ScrollPhysics — no UIScrollView. Flick, bounce, rubber-band. Trackpad two-finger scroll supported."
        caption.font = .systemFont(ofSize: 13, weight: .medium)
        caption.textColor = .secondaryLabel
        caption.numberOfLines = 0
        caption.textAlignment = .center

        hud.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        hud.textColor = .secondaryLabel
        hud.textAlignment = .center
        hud.text = "offset 0   v 0.00 pts/ms   idle"

        for i in 0..<rowCount {
            let row = UILabel()
            row.text = "   Row \(i)"
            row.textColor = .white
            row.font = .systemFont(ofSize: 18, weight: .semibold)
            row.backgroundColor = UIColor(hue: CGFloat(i % 12) / 12.0, saturation: 0.55, brightness: 0.92, alpha: 1)
            scrollView.contentView.addSubview(row)
            rows.append(row)
        }
        scrollView.contentHeight = CGFloat(rowCount) * rowHeight
        scrollView.onScroll = { [weak self] offsetY, velocityY, phase in
            guard let self else { return }
            self.hud.text = String(format: "offset %.0f   v %.2f pts/ms   %@",
                                    offsetY, velocityY, self.name(of: phase))
        }

        modeControl.selectedSegmentIndex = 0   // matches PhysicsScrollView's default (.keyframe)
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)

        for v in [caption, scrollView, hud, modeControl] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            caption.topAnchor.constraint(equalTo: g.topAnchor, constant: 8),
            caption.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
            caption.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: modeControl.topAnchor, constant: -8),

            modeControl.centerXAnchor.constraint(equalTo: g.centerXAnchor),
            modeControl.bottomAnchor.constraint(equalTo: hud.topAnchor, constant: -8),

            hud.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
            hud.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
            hud.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -8),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = scrollView.bounds.width
        for (i, row) in rows.enumerated() {
            row.frame = CGRect(x: 0, y: CGFloat(i) * rowHeight, width: width, height: rowHeight - 1)
        }
    }

    @objc private func modeChanged() {
        scrollView.decelerationMode = modeControl.selectedSegmentIndex == 0 ? .keyframe : .stepped
    }

    private func name(of phase: ScrollAxis.Phase) -> String {
        switch phase {
        case .idle: return "idle"
        case .dragging: return "dragging"
        case .decelerating: return "decelerating"
        }
    }
}
