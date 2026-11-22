// The platform's half of layout and painting (M1c plan, Task 3): fonts, text measurement, shaping, line breaking,
// text transforms, image decoding and path containment; since V5d, canvas bitmaps. CoreText and ImageIO on iOS (M1d); FakeRenderHost in tests.
//
// WidgetContainer is its only caller. Every method is noexcept in effect: a host call never throws and never calls
// back into the runtime. The host is never handed a URL, only the decoded bytes of a data: image WidgetContainer
// accepted. A HostFont or HostImage is self-contained: it stays valid after the host that made it is gone, because
// a published layer tree holds them (Global Constraints, "The layer tree is plain data").
#pragma once

#include <cstdint>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

#include <litehtml/document_container.h>

namespace wr {

namespace canvas {
struct CanvasOp;
} // namespace canvas

class HostFont {
public:
    virtual ~HostFont() = default;
};

class HostImage {
public:
    virtual ~HostImage() = default;
};

struct DecodedImage {
    std::shared_ptr<const HostImage> image;
    double width = 0, height = 0;
};

/// A run shaped with the font that measured it (Ruling 19): one glyph per entry, advances in CSS px.
struct ShapedText {
    std::vector<uint32_t> glyphs;
    std::vector<float> advances;
};

enum class Theme : uint8_t { Light, Dark };

/// A canvas's bitmap (V5d plan, Task 2): `width` × `height` px, transparent when made, y down. It runs the
/// interpreter's ops in order as they come and hands out its pixels as snapshots. A snapshot is a self-contained
/// HostImage (it outlives the canvas and the host, as a published tree holds it); the same snapshot is returned until
/// the next run. Used on the runtime's thread only; a snapshot may be drawn on any.
class HostCanvas {
public:
    virtual ~HostCanvas() = default;
    virtual void run(std::span<const canvas::CanvasOp> ops) = 0;
    virtual std::shared_ptr<const HostImage> snapshot() = 0;
};

class RenderHost {
public:
    virtual ~RenderHost() = default;
    /// A font for `description`, with its metrics filled in.
    virtual std::shared_ptr<const HostFont> createFont(const litehtml::font_description& description,
                                                       litehtml::font_metrics& metrics) = 0;
    virtual double textWidth(const HostFont& font, std::string_view utf8) = 0;
    /// nullptr: litehtml's own breaking.
    virtual std::shared_ptr<litehtml::text_breaker> createTextBreaker(const HostFont& font, const std::string& utf8) = 0;
    virtual ShapedText shape(const HostFont& font, std::string_view utf8) = 0;
    /// Text selection (sdk-v1 §5.10): the x offset of every UTF-16 boundary of `utf8` (its UTF-16 length + 1 values,
    /// the first at the text's start) where the host draws it with `font`, in CSS px from the text's left; right to left
    /// they descend. A boundary inside a surrogate pair has the pair's start offset. Empty when the host cannot tell:
    /// that text is then not selectable.
    virtual std::vector<float> caretOffsets(const HostFont& font, std::string_view utf8) {
        (void)font;
        (void)utf8;
        return {};
    }
    virtual void transformText(std::string& utf8, litehtml::text_transform transform) = 0;
    virtual double defaultFontSize() const = 0;
    virtual std::string defaultFontName() const = 0;
    /// `mimeType` is an `image/*` essence (DataUrl::mimeType); `bytes` the data: URL's body. nullopt: not decodable.
    virtual std::optional<DecodedImage> decodeImage(std::string_view mimeType, std::span<const uint8_t> bytes) = 0;
    virtual bool pathContains(const litehtml::vector_path& path, double x, double y) = 0;
    /// A canvas bitmap; nullptr when the host draws no canvases or could not allocate one (the canvas then draws
    /// nothing). The caller has already kept the size within the widget's canvas allowance.
    virtual std::unique_ptr<HostCanvas> createCanvas(int width, int height) {
        (void)width;
        (void)height;
        return nullptr;
    }
};

/// What a widget is laid out with. The viewport is (width, viewportHeight); its height is 0 by default, as today
/// (Ruling 16). The device pixel ratio is not a layout input (Ruling 17).
struct RenderOptions {
    double width = 300;
    double viewportHeight = 0;
    Theme theme = Theme::Light;
    /// SDK v1 §2.3 (V2a plan, Task 4): the theme's --tg-theme-* and --tg-color-scheme declarations, each !important,
    /// which the root element takes after its own style attribute (twidget edit 26). installRender sets them from the
    /// HostState's theme; HostState keeps them current.
    std::string rootDeclarations;
    /// SDK v1 §2.17 (widget-sandbox v0.4.0): the six --tg-content-safe-area-* declarations, each !important, which the
    /// root takes after the theme's. installRender sets them from the HostState's content safe area (0px until the host
    /// says); HostState keeps them current. Apart from the theme's, so either changes alone.
    std::string contentSafeAreaDeclarations;
    /// The spec renderer's root CSS (widget-sandbox v0.1.1, `packages/core/src/host/shadow-renderer.ts`), without its
    /// `:where()`: in the master sheet the author's rules win over it whatever their specificity. The body's margin is
    /// the UA layer's (the padding token), which ranks above this sheet (twidget edit 41).
    std::string hostCSS = "html { display: flow-root; position: relative; min-height: 0 } head { display: none } "
                          "body { display: block }";
    /// Whether RenderTree keeps renderInput, the test oracle (Ruling E11). Off in production: it would live in the
    /// widget's JS heap, and escaping expands it up to 6×.
    bool keepRenderInput = false;
    /// The device scale the tree will be drawn at (M1d plan, Task 1). litehtml snaps text and some boxes to device
    /// pixels while it paints (pixel_snap_scale, which LHDocument sets from the CTM at draw time); the runtime paints
    /// once, into the tree, so it snaps at the scale the app draws at. 1 keeps whole CSS pixels.
    double pixelSnapScale = 1;
    /// prefers-reduced-motion (twidget edit 29.5): reduce when true, the system's Reduce Motion (HostState::setReducedMotion,
    /// WRSession's setReducedMotion:); no preference until the host says.
    bool reducedMotion = false;
    /// Ruling E19: whether the boot's build cuts its matching at litehtml's 4,000,000 selector steps (a hostile boot);
    /// every patch is held to kPatchSelectorSteps (RenderTree.h). Off in the tests' fresh trees, which stand for what a
    /// patched document must equal.
    bool selectorStepCut = true;
};

/// What the root takes after its own style (twidget edit 26): the theme's declarations, then the content safe area's.
inline std::string rootDeclarationsOf(const RenderOptions& options) {
    if (options.contentSafeAreaDeclarations.empty()) {
        return options.rootDeclarations;
    }
    if (options.rootDeclarations.empty()) {
        return options.contentSafeAreaDeclarations;
    }
    return options.rootDeclarations + ";" + options.contentSafeAreaDeclarations;
}

} // namespace wr
