import UIKit

/// The on-screen half of the inspection surface.
///
/// The whole view is ONE accessibility element whose `accessibilityValue` is the dump, which is
/// what lets an XCUITest read model state out of process as a plain string. Without it, Tier 2
/// could only assert that elements exist.
public final class HarnessReadoutView: UIView {
    private let scrollView = UIScrollView()
    private let label = UILabel()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.label.numberOfLines = 0
        self.label.font = UIFont.monospacedSystemFont(ofSize: 9.0, weight: .regular)
        self.label.textColor = .secondaryLabel
        self.scrollView.addSubview(self.label)
        self.addSubview(self.scrollView)

        self.isAccessibilityElement = true
        self.accessibilityIdentifier = "harness.modelDump"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The most of the dump drawn on screen. The ACCESSIBILITY value always carries the whole dump (the
    /// Tier-2 contract); only the drawn label is capped. Drawing all of it made the harness's own
    /// readout the dominant cost of every edit in a large document — a 160-emoji paragraph spent ~80 %
    /// of a Format command's settle laying out and drawing this label (CoreText with emoji fallback,
    /// measured with `sample`, p15 fix wave) — which swamped the product's timing in the scaling tests.
    static let drawnCharacterLimit = 4000

    public func update(text: String) {
        let drawn = text as NSString
        if drawn.length > Self.drawnCharacterLimit {
            let cut = drawn.rangeOfComposedCharacterSequence(at: Self.drawnCharacterLimit).location
            self.label.text = drawn.substring(to: cut) + "\n… (\(drawn.length - cut) more characters in the accessibility value)"
        } else {
            self.label.text = text
        }
        self.accessibilityValue = text
        self.setNeedsLayout()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        self.scrollView.frame = self.bounds
        let size = self.label.sizeThatFits(
            CGSize(width: self.bounds.width, height: .greatestFiniteMagnitude))
        self.label.frame = CGRect(
            origin: .zero, size: CGSize(width: self.bounds.width, height: size.height))
        self.scrollView.contentSize = self.label.frame.size
    }
}
