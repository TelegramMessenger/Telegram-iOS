import Foundation
import UIKit
import Display
import AppBundle

/// How far a tear band overhangs the bubble horizontally. The bubble's fill and its outline are
/// drawn from a stretchable image inset by -1, so a band that stopped at the bubble's own width
/// would leave a hairline of edge beside it.
public let bubbleTearHorizontalOverhang: CGFloat = 4.0

/// How far a band overhangs vertically once it has absorbed a sliver, for the same reason.
public let bubbleTearVerticalOverhang: CGFloat = 4.0

/// A run of bubble this short between a band and the bubble's top or bottom edge is not worth
/// drawing: the band swallows it instead. A message whose only content is unsupported therefore
/// loses its bubble entirely, which is the intent.
public let bubbleTearSliverThreshold: CGFloat = 8.0

/// How far a `ChatMessageBackground`'s tear mask extends past its bounds. A mask layer clips to its
/// own bounds, and both the node's image view and its outline node are inset by -1.
public let bubbleTearMaskInset: CGFloat = 2.0

/// Height of the torn-paper edge graphics, and so the depth each band grows INTO the bubble at every
/// edge that is a real tear.
///
/// The fringe is carved out of the bubble rather than out of the hole: the band the caller asked for
/// is the clean gap the pill sits in, and the ragged transition needs room of its own on top of it.
///
/// Must match the assets, which are 400x10.
public let bubbleTearEdgeHeight: CGFloat = 10.0

/// Vertical trim on the TOP edge's growth, on top of `bubbleTearEdgeHeight`. Positive pulls the
/// upper ragged line closer to the content above it, negative pushes it away. Purely visual.
public let bubbleTearTopEdgeLift: CGFloat = 0.0

/// How far each torn-edge graphic is pulled toward the band's centre, away from the band's own
/// edge, so the two edges do not land on the same row and composite into a seam.
///
/// Positive moves the top graphic down and the bottom graphic up. Negative overlaps them outward
/// past the band instead — which is the other way to break the coincidence, if pulling them inward
/// exposes a hairline of the band rather than hiding one.
public let bubbleTearEdgeInset: CGFloat = -1.0

/// How far each torn-edge graphic stops short of the bubble's body on each side.
///
/// A hair under a full point: one pixel of the gap is there so the graphic's edge and the body's
/// edge do not land on the same column and antialias against each other. Negative would outset the
/// graphic past the body instead.
public let bubbleTearGraphicsHorizontalInset: CGFloat = 1.0 - UIScreenPixel

/// Horizontal room the bubble's TAIL occupies inside the background frame, on the tail's own side.
///
/// The frame is a rectangle; the silhouette is not. `messageBubbleImage` builds the shape from a
/// 33pt body plus a 6pt tail extension, and that column is reserved on one side for every merge
/// type — even the ones that draw no tail. Above and below the tail itself the column is empty, so
/// anything painted across the full frame width sticks out past the body there.
public let bubbleTearTailInset: CGFloat = 6.0

/// Which side of a band's frame is tail rather than bubble body.
public struct BubbleTearTailInsets: Equatable {
    public let left: CGFloat
    public let right: CGFloat

    public static let none = BubbleTearTailInsets(left: 0.0, right: 0.0)

    public init(left: CGFloat, right: CGFloat) {
        self.left = left
        self.right = right
    }

    /// Incoming bubbles carry the tail on the left, outgoing on the right.
    public init(type: ChatMessageBackgroundType) {
        switch type {
        case .none:
            self = .none
        case .incoming:
            self = BubbleTearTailInsets(left: bubbleTearTailInset, right: 0.0)
        case .outgoing:
            self = BubbleTearTailInsets(left: 0.0, right: bubbleTearTailInset)
        }
    }
}

/// One band cut out of the bubble background.
///
/// The edge flags exist because a band that ran off the bubble's top or bottom has no bubble beyond
/// it. Drawing a torn edge there would paint a ragged strip of bubble back outside the bubble's own
/// silhouette.
public struct BubbleTearBand: Equatable {
    /// In the torn node's own coordinate space.
    public let frame: CGRect
    /// There is bubble above this band, so its top edge is a real tear.
    public let hasTopEdge: Bool
    /// There is bubble below this band, so its bottom edge is a real tear.
    public let hasBottomEdge: Bool

    public init(frame: CGRect, hasTopEdge: Bool, hasBottomEdge: Bool) {
        self.frame = frame
        self.hasTopEdge = hasTopEdge
        self.hasBottomEdge = hasBottomEdge
    }

    public func offsetBy(dx: CGFloat, dy: CGFloat) -> BubbleTearBand {
        return BubbleTearBand(frame: self.frame.offsetBy(dx: dx, dy: dy), hasTopEdge: self.hasTopEdge, hasBottomEdge: self.hasBottomEdge)
    }
}

/// Normalises raw per-content-node zones into the bands actually cut out of a bubble of
/// `backgroundSize`. Zones arrive in background-relative coordinates; only their vertical extent
/// is read.
///
/// Resolve ONCE per layout and hand the result to every surface. Two surfaces that each resolved
/// their own copy could drift apart.
public func resolveBubbleTearBands(_ zones: [CGRect], backgroundSize: CGSize) -> [BubbleTearBand] {
    if zones.isEmpty || backgroundSize.height <= 0.0 {
        return []
    }

    // Clip to the bubble and drop anything that falls outside it: a zone can be stale by one
    // layout pass, and a phantom band in a resized bubble is worse than a missing one.
    var bands: [(min: CGFloat, max: CGFloat)] = []
    for zone in zones {
        let minY = max(0.0, zone.minY)
        let maxY = min(backgroundSize.height, zone.maxY)
        if maxY > minY {
            bands.append((min: minY, max: maxY))
        }
    }
    if bands.isEmpty {
        return []
    }

    bands.sort(by: { $0.min < $1.min })
    bands = mergeBubbleTearBands(bands)

    for i in 0 ..< bands.count {
        // Grow into the bubble to make room for the torn-paper edges. The caller's zone is the
        // clean gap the pill sits in; the ragged transition must not eat into it.
        bands[i].min -= bubbleTearEdgeHeight + bubbleTearTopEdgeLift
        bands[i].max += bubbleTearEdgeHeight

        // Then absorb slivers, measured against the GROWN band — a 12pt run of bubble that only
        // survived because the growth had not been applied yet is not a run worth drawing.
        if bands[i].min <= bubbleTearSliverThreshold {
            bands[i].min = -bubbleTearVerticalOverhang
        }
        if backgroundSize.height - bands[i].max <= bubbleTearSliverThreshold {
            bands[i].max = backgroundSize.height + bubbleTearVerticalOverhang
        }
    }
    // Growing and absorbing both only lower `min` and raise `max`, so the sort still holds — but
    // either can make two bands touch that did not before, so merge again.
    bands = mergeBubbleTearBands(bands)

    return bands.map { band in
        BubbleTearBand(
            frame: CGRect(
                x: -bubbleTearHorizontalOverhang,
                y: band.min,
                width: backgroundSize.width + bubbleTearHorizontalOverhang * 2.0,
                height: band.max - band.min
            ),
            // An edge is a real tear exactly when it lies inside the bubble. Absorption is the only
            // thing that puts an edge outside, and it puts it a whole overhang out, so this reads
            // the outcome rather than tracking a flag through the merges.
            hasTopEdge: band.min > 0.0,
            hasBottomEdge: band.max < backgroundSize.height
        )
    }
}

/// Merges bands that overlap or touch. Input must be sorted ascending by `min`.
private func mergeBubbleTearBands(_ bands: [(min: CGFloat, max: CGFloat)]) -> [(min: CGFloat, max: CGFloat)] {
    var result: [(min: CGFloat, max: CGFloat)] = []
    for band in bands {
        if var last = result.last, band.min <= last.max {
            last.max = max(last.max, band.max)
            result[result.count - 1] = last
        } else {
            result.append(band)
        }
    }
    return result
}

/// The torn-paper edge graphics, loaded once. Both are 400x10 white-on-alpha strips, tileable
/// horizontally: `Up` is solid along its top with the fringe pointing down (the bottom edge of the
/// bubble piece ABOVE a band), `Down` is its mirror.
///
/// Prepared as tiling templates: tiling because a band is as wide as the bubble plus its overhang
/// and the asset is a fixed 400pt, template so the mask does not depend on the asset's own colour.
///
/// `shared` is a `var` so tests can substitute stubs. The real assets live in the app bundle, which
/// a unit-test host has no access to — without substitution the band geometry could not be covered
/// at all. Nothing in the app writes it.
final class BubbleTearEdgeImages {
    static var shared = BubbleTearEdgeImages(
        up: UIImage(bundleImageName: "Chat/Message/BubbleTearUp"),
        down: UIImage(bundleImageName: "Chat/Message/BubbleTearDown")
    )

    let up: UIImage?
    let down: UIImage?

    init(up: UIImage?, down: UIImage?) {
        self.up = BubbleTearEdgeImages.prepare(up)
        self.down = BubbleTearEdgeImages.prepare(down)
    }

    private static func prepare(_ image: UIImage?) -> UIImage? {
        return image?
            .resizableImage(withCapInsets: UIEdgeInsets(), resizingMode: .tile)
            .withRenderingMode(.alwaysTemplate)
    }
}

/// One hole in the mask: a black rectangle, with a torn-paper graphic along each edge that faces
/// bubble.
///
/// The graphics are WHITE over the black rectangle, so they hand a ragged strip back to the bubble.
/// Their solid side abuts the band's own edge, which is what makes the bubble read as continuing
/// into the graphic rather than stopping short of it.
///
/// The band arrives already grown by `bubbleTearEdgeHeight` at every torn edge, so the strip the
/// graphic reclaims is bubble the resolver set aside for it — the clean gap the pill sits in is
/// what remains between the two graphics.
final class BubbleTearBandView: UIView {
    private var topEdgeView: UIImageView?
    private var bottomEdgeView: UIImageView?

    private var hasTopEdge = false
    private var hasBottomEdge = false
    private var tailInsets: BubbleTearTailInsets = .none

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = .black
        // Belt and braces: nothing inside a band may reach past it, whatever a graphic's frame ends
        // up being.
        self.clipsToBounds = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// `size` is passed rather than read from `bounds`, and the graphics are positioned HERE rather
    /// than only in `layoutSubviews`, because a band view lives inside a `mask` — and a mask view is
    /// not in the view hierarchy, so there is no layout pass to rely on. Left to `layoutSubviews`,
    /// each graphic keeps the frame `UIImageView(image:)` gave it: the asset's own 400x10 at the
    /// origin, which overhangs the bubble by hundreds of points.
    func update(size: CGSize, hasTopEdge: Bool, hasBottomEdge: Bool, tailInsets: BubbleTearTailInsets) {
        self.tailInsets = tailInsets
        if hasTopEdge != self.hasTopEdge {
            self.hasTopEdge = hasTopEdge
            self.topEdgeView = BubbleTearBandView.updateEdgeView(self.topEdgeView, isPresent: hasTopEdge, image: BubbleTearEdgeImages.shared.up, in: self)
        }
        if hasBottomEdge != self.hasBottomEdge {
            self.hasBottomEdge = hasBottomEdge
            self.bottomEdgeView = BubbleTearBandView.updateEdgeView(self.bottomEdgeView, isPresent: hasBottomEdge, image: BubbleTearEdgeImages.shared.down, in: self)
        }
        self.layoutEdgeViews(in: size)
    }

    private static func updateEdgeView(_ current: UIImageView?, isPresent: Bool, image: UIImage?, in container: UIView) -> UIImageView? {
        if !isPresent {
            current?.removeFromSuperview()
            return nil
        }
        if let current {
            return current
        }
        guard let image else {
            return nil
        }
        let view = UIImageView(image: image)
        view.tintColor = .white
        container.addSubview(view)
        return view
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.layoutEdgeViews(in: self.bounds.size)
    }

    private func layoutEdgeViews(in size: CGSize) {
        // The graphics stop at the bubble's own rectangular silhouette even though the band
        // overhangs it. The black band MUST overhang — that is what stops a hairline of bubble edge
        // surviving beside it — but the graphics are WHITE, and in the backdrop's mask white ADDS.
        // Run them the full width of the band and they paint wallpaper back outside the bubble, as
        // two stripes poking out of its sides.
        //
        // `tailInsets` because the frame is not the body: the tail column is reserved on one side
        // for every merge type, and above and below the tail itself it is empty.
        let graphicsInset = bubbleTearHorizontalOverhang + bubbleTearGraphicsHorizontalInset
        let graphicsX = graphicsInset + self.tailInsets.left
        let graphicsWidth = max(0.0, size.width - graphicsInset * 2.0 - self.tailInsets.left - self.tailInsets.right)

        // `bubbleTearEdgeHeight` rather than the image's own height: it is the same number, but it
        // is also the depth the resolver grew this band by, and the two must not be able to drift.
        if let topEdgeView {
            // One pixel short at the BOTTOM. The image is tiled, and a tile that does not divide the
            // view's device-pixel height wraps — putting the graphic's own solid top row back at its
            // fringe end as a half-pixel white stripe. Only the top graphic shows it: tiling starts
            // at the view's origin, so the wrap lands at the bottom, which for the bottom graphic is
            // its solid side.
            topEdgeView.frame = CGRect(x: graphicsX, y: bubbleTearEdgeInset, width: graphicsWidth, height: bubbleTearEdgeHeight - UIScreenPixel)
        }
        if let bottomEdgeView {
            bottomEdgeView.frame = CGRect(x: graphicsX, y: size.height - bubbleTearEdgeHeight - bubbleTearEdgeInset, width: graphicsWidth, height: bubbleTearEdgeHeight)
        }
    }
}

/// The bands that punch the holes. Shared by both mask surfaces so they cannot disagree about
/// pooling or about how a band is drawn.
final class BubbleTearBandPool {
    private weak var container: UIView?
    private(set) var views: [BubbleTearBandView] = []

    init(container: UIView) {
        self.container = container
    }

    /// `bands` are in the container's own coordinate space.
    func update(bands: [BubbleTearBand], tailInsets: BubbleTearTailInsets, animation: ListViewItemUpdateAnimation) {
        let previousCount = self.views.count

        while self.views.count > bands.count {
            self.views.removeLast().removeFromSuperview()
        }
        while self.views.count < bands.count {
            let bandView = BubbleTearBandView()
            self.container?.addSubview(bandView)
            self.views.append(bandView)
        }

        for (index, band) in bands.enumerated() {
            let bandView = self.views[index]
            if index >= previousCount {
                // A band that did not exist a moment ago has no meaningful previous frame, and
                // animating it from `.zero` would sweep a hole across the bubble.
                bandView.frame = band.frame
            } else {
                animation.animator.updateFrame(layer: bandView.layer, frame: band.frame, completion: nil)
            }
            // After the frame, and with the size passed explicitly: these views live inside a `mask`,
            // which is not in the view hierarchy, so there is no layout pass to position their
            // contents for us.
            bandView.update(size: band.frame.size, hasTopEdge: band.hasTopEdge, hasBottomEdge: band.hasBottomEdge, tailInsets: tailInsets)
        }
    }
}

/// A mask surface that is opaque everywhere except at the tear bands.
///
/// White maps to alpha 1 and black to alpha 0 under `luminanceToAlpha`, so a white view with black
/// band subviews punches holes in whatever it masks. Used by `ChatMessageBackground`, which has no
/// mask of its own.
final class BubbleTearMaskView: UIView {
    private(set) lazy var bandPool = BubbleTearBandPool(container: self)

    /// Returns nil when `luminanceToAlpha` is unavailable — it is a private `CAFilter`. The caller
    /// must then leave the bubble untorn: an unfiltered white view would mask nothing away, but a
    /// filtered-black one would hide everything, and there is no safe middle.
    static func make() -> BubbleTearMaskView? {
        guard let filter = CALayer.luminanceToAlpha() else {
            return nil
        }
        let view = BubbleTearMaskView(frame: CGRect())
        view.layer.filters = [filter]
        // A band overhangs the bubble by more than this mask does. Nothing it draws is meant to be
        // seen out there, so bound it rather than trust that it stays invisible.
        view.clipsToBounds = true
        return view
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = .white
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(bands: [BubbleTearBand], tailInsets: BubbleTearTailInsets, animation: ListViewItemUpdateAnimation) {
        self.bandPool.update(bands: bands, tailInsets: tailInsets, animation: animation)
    }
}

/// The wallpaper backdrop's mask: the bubble silhouette, optionally with tear bands cut out of it.
///
/// Two shapes in one view, so the node's `mask` identity never changes and its framing code stays
/// a single path:
///
/// - **Untorn** — the shape image, unfiltered. A `CALayer` mask reads alpha and ignores colour,
///   which is why the black-filled `bubbleMaskForType` image has always worked here.
/// - **Torn** — `luminanceToAlpha` on this view, the shape image re-rendered as a WHITE template,
///   and black bands on top. The template is load-bearing: filtering the black-filled image would
///   map it to alpha 0 and erase the entire backdrop rather than punching bands out of it.
///   Template rendering preserves both the alpha channel and the image's stretch caps, so the
///   silhouette is unchanged.
///
/// Public only because `ChatMessageBubbleBackdrop.maskView` is: the instant-video content node
/// reaches for that view to hang its own round mask layer on. Nothing outside this module needs
/// any member of it.
public final class BubbleBackdropMaskView: UIView {
    let shapeView = UIImageView()
    private(set) lazy var bandPool = BubbleTearBandPool(container: self)

    private let tearFilter = CALayer.luminanceToAlpha()
    private var isTorn = false

    var image: UIImage? {
        didSet {
            self.applyImage()
        }
    }

    public init() {
        super.init(frame: CGRect())

        // A band overhangs the bubble by more than this mask does. Nothing it draws is meant to be
        // seen out there, so bound it rather than trust that it stays invisible.
        self.clipsToBounds = true
        self.addSubview(self.shapeView)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        self.shapeView.frame = self.bounds
    }

    /// Resize this view AND the silhouette inside it on one curve.
    ///
    /// Load-bearing, and invisible from the call site: the shape image is what the backdrop's mask
    /// actually is, and `layoutSubviews` re-seats it at the DESTINATION size on the next commit,
    /// unanimated. Animating only this view therefore leaves the silhouette snapping behind an
    /// animating clip — the bubble's wallpaper backdrop reads as un-animated while its layer is
    /// demonstrably animating. That is what `ChatMessageBubbleBackdrop` looked like between the
    /// bubble-tear change (which moved the image from this view into a child) and this method.
    ///
    /// `layoutSubviews` stays, as the backstop for every path that does not animate: the mask's
    /// creation in `setType`, and the node's own `frame` didSet. On an animated path it re-asserts
    /// the same value the animator already wrote as the model, so it is a no-op there.
    func updateFrame(_ frame: CGRect, animator: ControlledTransitionAnimator) {
        animator.updateFrame(layer: self.layer, frame: frame, completion: nil)
        animator.updateFrame(layer: self.shapeView.layer, frame: CGRect(origin: CGPoint(), size: frame.size), completion: nil)
    }

    func updateFrame(_ frame: CGRect, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: self, frame: frame)
        transition.updateFrame(view: self.shapeView, frame: CGRect(origin: CGPoint(), size: frame.size))
    }

    func updateFrame(_ frame: CGRect, transition: CombinedTransition) {
        transition.updateFrame(layer: self.layer, frame: frame)
        transition.updateFrame(layer: self.shapeView.layer, frame: CGRect(origin: CGPoint(), size: frame.size))
    }

    func update(bands: [BubbleTearBand], tailInsets: BubbleTearTailInsets, animation: ListViewItemUpdateAnimation) {
        let shouldBeTorn = !bands.isEmpty && self.tearFilter != nil
        if shouldBeTorn != self.isTorn {
            self.isTorn = shouldBeTorn
            self.layer.filters = shouldBeTorn ? self.tearFilter.flatMap({ [$0] }) : nil
            self.applyImage()
        }
        // With no filter installed the bands would be opaque black rather than holes, so a build
        // without `luminanceToAlpha` gets no bands at all and renders the bubble untorn.
        self.bandPool.update(bands: self.isTorn ? bands : [], tailInsets: tailInsets, animation: animation)
    }

    private func applyImage() {
        if self.isTorn {
            self.shapeView.image = self.image?.withRenderingMode(.alwaysTemplate)
            self.shapeView.tintColor = .white
        } else {
            self.shapeView.image = self.image
        }
    }
}
