import UIKit

/// The network marker (widget-sandbox v0.2, sdk-v1 §5.11, integration.md): a widget whose message has `can_query` may
/// send data to its bot's server on a tap, and the bubble says so with this mark, exactly there and nowhere else. A tap
/// explains it (`onTap`). A round badge the colour of the date pill with a white glyph.
public final class MessageWidgetNetworkMarkerView: UIButton {
    static let size = CGSize(width: 20.0, height: 20.0)

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let configuration = UIImage.SymbolConfiguration(pointSize: 10.0, weight: .semibold)
        self.setImage(UIImage(systemName: "antenna.radiowaves.left.and.right", withConfiguration: configuration), for: .normal)
        self.tintColor = .white
        self.layer.cornerRadius = MessageWidgetNetworkMarkerView.size.height / 2.0
        self.accessibilityIdentifier = "widget.networkMarker"
        self.addTarget(self, action: #selector(self.tapped), for: .touchUpInside)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(fill: UIColor) {
        self.backgroundColor = fill
    }

    @objc private func tapped() {
        self.onTap?()
    }
}
