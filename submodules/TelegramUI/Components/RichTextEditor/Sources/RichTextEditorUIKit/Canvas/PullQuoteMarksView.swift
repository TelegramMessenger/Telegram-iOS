#if canImport(UIKit)
import UIKit
#if !SWIFT_PACKAGE
import AppBundle
#endif

/// Non-interactive overlay hosting two tinted quote-mark image views per pull-quote pill: an opening mark at the
/// pill's top-left and a closing mark at the bottom-right. The pill fill is drawn by the barless
/// `pullQuoteUnderlay`; the marks sit above it. Images are the app's `RichText/QuoteOpen` and `RichText/QuoteClose`
/// (template, tinted to the accent) — each pre-oriented, so the close mark needs no rotation. Where the bundled
/// asset is unavailable (SwiftPM/Demo/tests, or a failed load) a generated stub image stands in, so the image —
/// and thus the mark geometry, which is sized from `UIImage.size` — is never nil.
@available(iOS 13.0, *)
public final class PullQuoteMarksView: UIView {
    public var accentColor: UIColor = .systemBlue { didSet { for (o, c) in pool { o.tintColor = accentColor; c.tintColor = accentColor } } }
    private var pool: [(open: UIImageView, close: UIImageView)] = []

    /// Fixed size of the generated stub mark (matches the shipped `RichText/QuoteOpen`/`QuoteClose` assets),
    /// used only where the real asset is unavailable.
    private static let stubMarkSize = CGSize(width: 12, height: 10)
    /// A generated placeholder mark for when the bundled asset can't load — under SwiftPM/Demo/tests (no
    /// AppBundle), or a failed load in the app. Keeps `openImage`/`closeImage` non-optional so the mark
    /// geometry is uniformly image-size-driven with no nil branch.
    private static func makeStubMarkImage() -> UIImage {
        UIGraphicsImageRenderer(size: stubMarkSize).image { ctx in
            UIColor.black.setFill()
            ctx.cgContext.fill(CGRect(origin: .zero, size: stubMarkSize))
        }.withRenderingMode(.alwaysTemplate)
    }

    private static let openImage: UIImage = {
        #if SWIFT_PACKAGE
        return makeStubMarkImage()
        #else
        return UIImage(bundleImageName: "RichText/QuoteOpen")?.withRenderingMode(.alwaysTemplate) ?? makeStubMarkImage()
        #endif
    }()
    private static let closeImage: UIImage = {
        #if SWIFT_PACKAGE
        return makeStubMarkImage()
        #else
        return UIImage(bundleImageName: "RichText/QuoteClose")?.withRenderingMode(.alwaysTemplate) ?? makeStubMarkImage()
        #endif
    }()

    /// Natural point size (`UIImage.size`) of each mark asset — the source of truth for the mark frame
    /// dimensions in `pullQuoteMarkRects()`. Always available (a generated stub stands in where the bundled
    /// asset is not).
    public static var openImageNaturalSize: CGSize { openImage.size }
    public static var closeImageNaturalSize: CGSize { closeImage.size }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false   // decorative — never intercept touches
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Reconciles two image views per pill. Extra pooled views are hidden.
    public func sync(marks: [(open: CGRect, close: CGRect)]) {
        for (i, m) in marks.enumerated() {
            let pair = i < pool.count ? pool[i] : {
                let o = UIImageView(); let c = UIImageView()
                o.contentMode = .scaleAspectFit; c.contentMode = .scaleAspectFit
                o.tintColor = accentColor; c.tintColor = accentColor
                addSubview(o); addSubview(c)
                pool.append((o, c))
                return (o, c)
            }()
            // Distinct pre-oriented assets: open glyph top-left, close glyph bottom-right (no rotation).
            pair.open.image = PullQuoteMarksView.openImage; pair.close.image = PullQuoteMarksView.closeImage
            pair.open.frame = m.open; pair.close.frame = m.close
            pair.open.isHidden = false; pair.close.isHidden = false
        }
        for i in marks.count..<pool.count { pool[i].open.isHidden = true; pool[i].close.isHidden = true }
    }
}
#endif
