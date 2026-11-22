// The runtime's own litehtml container (M1c plan, Task 3; the recording is Task 4's). It has three halves:
// - Layout: fonts, text measurement, breaking, transforms, image decoding and clip-path containment are the
//   RenderHost's; the media features and the other fixed answers are LHContainer's (Ruling 16).
// - Loads: litehtml has no I/O of its own, so every load is a call here (load_image, get_image_size, draw_image,
//   import_css, link). A data: URL whose type is image/* is decoded by the host, once, from its bytes; every other
//   request is refused and counted (Review Focus 3). The host is never handed a URL.
// - Paint: record() draws a laid-out document into a new LayerTree (Task 4), one item per paint call. The tree is plain
//   data: fonts and images by shared_ptr, every argument copied, nothing pointing into the document or this container.
// Fonts and decoded images are cached by font description and by the data: URL's text (Ruling 19), so builds and patches
// reuse the same objects; after every flush that publishes, prune drops what no element of the document names.
// - Profile 1 (V4 plan, Task 3b): litehtml's profile hooks (twidget edit 29) are answered with CSSPolicy.h's verdicts,
//   so a declaration, a selector, an at-rule, an @media query and an @supports condition reach the document as the
//   profile keeps them. The master sheet (litehtml's, the profile's UA sheet and the host's) passes whole: litehtml
//   parses it between trusted_styles(true) and (false), once per process, and caches it. Every hook is a pure function
//   of its text (litehtml's caches key on text, with sanitizer_key), and none reports a diagnostic.
//
// A litehtml document calls its container until it is destroyed (its destructor deletes its fonts here), so every
// document laid out through a WidgetContainer must be destroyed before it.
#pragma once

#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include <litehtml/document_container.h>

#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderHost.h"

namespace wr {

/// Task 10b: what a walk of litehtml's paint order (LayerMirror) hears of the calls draw() makes outside an item's own
/// paint, which the container hands it instead of recording them. The arguments are draw()'s, in document coordinates.
class WalkListener {
public:
    virtual ~WalkListener() = default;
    virtual void walkSetClip(const litehtml::position& pos, const litehtml::border_radiuses& radius) = 0;
    virtual void walkDelClip() = 0;
    virtual void walkSuspendClips() = 0;
    virtual void walkResumeClips() = 0;
    virtual void walkBeginGroup(const litehtml::paint_group& group) = 0;
    virtual void walkEndGroup() = 0;
    virtual void walkClipPath(const litehtml::vector_path& path) = 0;
    virtual void walkBackdrop(const litehtml::filter_paint& filter) = 0;
    /// draw_filtered: `paint` runs the filtered contents (the walk goes on inside it).
    virtual void walkFiltered(const litehtml::filter_paint& filter, const std::function<void()>& paint) = 0;
    /// A paint call outside every capture: something the walk cannot place.
    virtual void walkStray() = 0;
};

class WidgetContainer final : public litehtml::document_container {
public:
    WidgetContainer(RenderHost& host, RenderOptions options);
    RenderHost& host() const { return m_host; }

    /// A canvas element's image source (V5d plan, Task 4): `twcanvas:<serial>:<width>:<height>`, which the builder gives
    /// a rendered <canvas> (litehtml lays it out as an image). Its size is the canvas's width and height, bitmap or
    /// not; what it draws, the source's pixels for the serial (nullopt: nothing yet).
    using CanvasSource = std::function<std::optional<DecodedImage>(uint64_t serial)>;
    void setCanvasSource(CanvasSource source) { m_canvasSource = std::move(source); }
    struct CanvasURL {
        uint64_t serial = 0;
        uint32_t width = 0, height = 0;
    };
    static std::string canvasURL(const CanvasURL& canvas);
    /// The source a refused <img src> renders (V4 plan, Task 6): the builder writes it with data-tg-placeholder, and
    /// the container answers it with placeholderSVG, decoded by the host like any image (RB §3.5).
    static constexpr std::string_view kPlaceholderURL = "twplaceholder:";
    /// widget-sandbox v0.1.0's placeholder, url-policy.ts decoded: 48 × 48, a #8882 ground, mountains and a sun in
    /// #8886. The one SVG the host is ever handed.
    static std::string_view placeholderSVG();
    /// An image source decoded as layout decides it (profile 1's image types, and the placeholder), but kept nowhere
    /// here: an <img>'s state (V5d plan, Task 5; CanvasState shares it). nullopt when refused or not decodable.
    std::optional<DecodedImage> decodeImageUncached(std::string_view src);
    /// The image layout already decoded for `src`, if it did: a lookup that adds nothing.
    std::optional<DecodedImage> decodedByLayout(std::string_view src) const;
    /// Tests: the fonts and the images (refused URLs included) the caches hold.
    size_t cachedFonts() const { return m_fonts.size(); }
    size_t cachedImages() const { return m_images.size(); }
    static std::optional<CanvasURL> parseCanvasURL(std::string_view url);
    ~WidgetContainer() override;
    WidgetContainer(const WidgetContainer&) = delete;
    WidgetContainer& operator=(const WidgetContainer&) = delete;

    const RenderOptions& options() const { return m_options; }
    /// Takes effect at the next question litehtml asks; a width or theme change is applied by the next flush's patch
    /// session (twidget edits 79, 80).
    void setOptions(RenderOptions options);
    /// Every load request refused so far: one per refused call, never reset.
    uint64_t refusedLoads() const { return m_refusedLoads; }
    /// A build begins: the limits reported (limitsHit) count from here.
    void beginBuild();
    /// The caches cut to what `document` uses: the font of each element (its font handle's description) and the images
    /// each names (its background layers' URLs, its list-style-image, an <img>'s src); every other entry, a refused URL
    /// included, is erased. A load site missed here costs a decode again, never a dangling handle (a handle owns its
    /// font, a tree its images).
    void prune(litehtml::document& document);
    /// The render-limit kinds litehtml reported through sanitizer_limit since the last beginBuild, each once, in the
    /// order first reported (Ruling 7: Task 5 posts the first of each kind).
    const std::vector<std::string>& limitsHit() const { return m_limitsHit; }
    /// Draws `document` (laid out through this container) into a new tree: document::draw at (0, 0) with no clip, so
    /// nothing is culled. The tree's size is the document's, and it outlives the document and this container.
    std::shared_ptr<const LayerTree> record(litehtml::document& document);
    /// Task 10b: while a walk runs (between beginWalk and endWalk) and no capture is open, the traversal's own calls go
    /// to `listener` and record nothing; capture() records an item's own paint into `target` as record() records every
    /// call, layers and all. The paint calls draw() makes outside an item's own paint are only the traversal's.
    void beginWalk(WalkListener& listener);
    void endWalk();
    void capture(Layer& target, const std::function<void()>& paint);

    // litehtml::document_container. Layout questions go to the host.
    litehtml::uint_ptr create_font(const litehtml::font_description& descr, const litehtml::document* doc,
                                   litehtml::font_metrics* fm) override;
    void delete_font(litehtml::uint_ptr hFont) override;
    /// RenderHost::caretOffsets for the font behind litehtml's handle; empty for no font.
    std::vector<float> caretOffsets(litehtml::uint_ptr hFont, std::string_view utf8) const;
    litehtml::pixel_t text_width(const char* text, litehtml::uint_ptr hFont) override;
    std::shared_ptr<litehtml::text_breaker> create_text_breaker(const std::string& text, litehtml::uint_ptr hFont) override;
    /// twidget edit 47 (fidelity plan, Task 13): each unit's level from UAX #9 over the line's text (bidi::levels), a
    /// unit at its first strong character. Laid out inside render(); the work is linear in the line's text.
    bool bidi_levels(const std::vector<std::string>& runs, bool rtl, std::vector<uint8_t>& levels) override;
    void transform_text(std::string& text, litehtml::text_transform tt) override;
    litehtml::pixel_t pt_to_px(float pt) const override;
    litehtml::pixel_t get_default_font_size() const override;
    const char* get_default_font_name() const override;
    void get_viewport(litehtml::position& viewport) const override;
    void get_media_features(litehtml::media_features& media) const override;
    void get_language(std::string& language, std::string& culture) const override;
    litehtml::element::ptr create_element(const char* tag_name, const litehtml::string_map& attributes,
                                          const std::shared_ptr<litehtml::document>& doc) override;
    bool point_in_clip_path(const litehtml::vector_path& path, litehtml::pixel_t x, litehtml::pixel_t y) override;
    void sanitizer_limit(const char* what) override;

    // Profile 1 (twidget edit 29): everything passes while the master sheet is parsed (trusted_styles).
    void trusted_styles(bool trusted) override { m_trusted = trusted; }
    bool sanitize_at_rule(const std::string& name) override;
    bool profile_declaration(std::string& name, litehtml::css_token_vector& value, bool& important) override;
    bool profile_substituted(const std::string& name, litehtml::css_token_vector& value) override;
    void sanitize_selector_list(std::vector<litehtml::css_token_vector>& groups) override;
    bool sanitize_media_query(const litehtml::css_token_vector& prelude) override;
    int evaluate_supports(const litehtml::css_token_vector& condition) override;
    uint32_t sanitizer_key() const override { return kSanitizerKey; }
    /// litehtml's caches keep this container's parses apart from a container whose hooks differ ("WR" + version 4).
    static constexpr uint32_t kSanitizerKey = 0x57520004;

    // Loads: data: images, or refused and counted. `baseurl` is never used: a relative URL is never resolved.
    void load_image(const char* src, const char* baseurl, bool redraw_on_ready) override;
    void get_image_size(const char* src, const char* baseurl, litehtml::size& sz) override;
    void import_css(std::string& text, const std::string& url, std::string& baseurl) override;
    void link(const std::shared_ptr<litehtml::document>& doc, const litehtml::element::ptr& el) override;

    // Inert: taps and pointer state belong to the runtime (M1d).
    void on_anchor_click(const char* url, const litehtml::element::ptr& el) override;
    bool on_element_click(const litehtml::element::ptr& el) override;
    void on_mouse_event(const litehtml::element::ptr& el, litehtml::mouse_event event) override;
    void set_cursor(const char* cursor) override;
    void set_caption(const char* caption) override;
    void set_base_url(const char* base_url) override;

    // Paint, while record() runs (outside it they record nothing; draw_filtered and draw_isolated still paint).
    // litehtml passes a group's contents the hdc it passed begin_group, so items go to the innermost open layer, which
    // is the one `hdc` names inside draw_filtered's and draw_isolated's paint; the clip ops take no hdc and go there too.
    void draw_text(litehtml::uint_ptr hdc, const char* text, litehtml::uint_ptr hFont, litehtml::web_color color,
                   const litehtml::position& pos) override;
    void draw_list_marker(litehtml::uint_ptr hdc, const litehtml::list_marker& marker) override;
    void draw_image(litehtml::uint_ptr hdc, const litehtml::background_layer& layer, const std::string& url,
                    const std::string& base_url) override;
    void draw_solid_fill(litehtml::uint_ptr hdc, const litehtml::background_layer& layer,
                         const litehtml::web_color& color) override;
    void draw_linear_gradient(litehtml::uint_ptr hdc, const litehtml::background_layer& layer,
                              const litehtml::background_layer::linear_gradient& gradient) override;
    void draw_radial_gradient(litehtml::uint_ptr hdc, const litehtml::background_layer& layer,
                              const litehtml::background_layer::radial_gradient& gradient) override;
    void draw_conic_gradient(litehtml::uint_ptr hdc, const litehtml::background_layer& layer,
                             const litehtml::background_layer::conic_gradient& gradient) override;
    void draw_borders(litehtml::uint_ptr hdc, const litehtml::borders& borders, const litehtml::position& draw_pos,
                      bool root) override;
    void draw_box_shadow(litehtml::uint_ptr hdc, const litehtml::position& box, const litehtml::border_radiuses& radius,
                         const litehtml::shadow_paint& shadow) override;
    void draw_path(litehtml::uint_ptr hdc, const litehtml::vector_path& path) override;
    void draw_backdrop(litehtml::uint_ptr hdc, const litehtml::filter_paint& filter) override;
    void set_clip(const litehtml::position& pos, const litehtml::border_radiuses& bdr_radius) override;
    void del_clip() override;
    void suspend_clips() override;
    void resume_clips() override;
    void set_clip_path(const litehtml::vector_path& path) override;
    /// Opens a Group layer holding `group`; end_group closes it.
    void begin_group(litehtml::uint_ptr hdc, const litehtml::paint_group& group) override;
    void end_group(litehtml::uint_ptr hdc) override;
    /// Opens a Filter layer with the steps copied and paints into it.
    void draw_filtered(litehtml::uint_ptr hdc, const litehtml::filter_paint& filter,
                       const std::function<void(litehtml::uint_ptr)>& paint) override;
    /// Opens an Isolated layer with `box` and paints into it.
    void draw_isolated(litehtml::uint_ptr hdc, const litehtml::position& box,
                       const std::function<void(litehtml::uint_ptr)>& paint) override;
    /// false: nothing is cached, so litehtml paints for real.
    bool draw_cached(litehtml::uint_ptr hdc, const litehtml::position& box, uint64_t key,
                     const std::function<void(litehtml::uint_ptr)>& paint) override;

private:
    /// What a font handle litehtml holds points to: its own reference to the host font, so the handle stays valid
    /// until delete_font whatever the cache drops, and to the description it was made for (a text item carries both).
    struct FontHandle {
        std::shared_ptr<const HostFont> font;
        std::shared_ptr<const litehtml::font_description> description;
    };
    struct CachedFont {
        std::shared_ptr<const HostFont> font;
        /// Made once per cached font and shared by its handles and every text item in it (Ruling E4): the family is
        /// the computed font-family text verbatim, which only the CSS caps bound.
        std::shared_ptr<const litehtml::font_description> description;
        litehtml::font_metrics metrics;
    };
    /// A URL's decision. Decoded and Undecodable are image/* data: URLs, handed to the host; Undecodable is one it
    /// could not decode, which loads nothing but is not a refusal.
    enum class Load : uint8_t { Refused, Decoded, Undecodable };
    struct CachedImage {
        Load load = Load::Refused;
        DecodedImage image;
    };

    /// The handle behind litehtml's uint_ptr; null for litehtml's 0 ("no font").
    static const FontHandle* handleOf(litehtml::uint_ptr hFont);
    /// The host font a handle stands for; null for litehtml's 0 ("no font").
    static const std::shared_ptr<const HostFont>& fontOf(litehtml::uint_ptr hFont);
    /// The decision for `src` (not empty), made once and kept while the document names it (prune); it does not count
    /// refusals.
    const CachedImage& decide(std::string_view src);
    /// The layer a paint call appends to: the innermost open one; null outside record().
    Layer* openLayer() const { return m_open.empty() ? nullptr : m_open.back(); }
    void append(PaintItem item);

    RenderHost& m_host;
    CanvasSource m_canvasSource;
    RenderOptions m_options;
    std::string m_defaultFontName;
    uint64_t m_refusedLoads = 0;
    std::map<std::string, CachedFont, std::less<>> m_fonts;
    std::map<std::string, CachedImage, std::less<>> m_images;
    std::vector<std::string> m_limitsHit;
    /// While record() runs: the open layers, its root first. Each is owned by the tree being built. During a capture,
    /// its target first.
    std::vector<Layer*> m_open;
    /// While a walk runs (Task 10b).
    WalkListener* m_walk = nullptr;
    /// Whether a traversal call goes to the walk: a walk runs and no capture is open.
    bool walking() const { return m_walk && m_open.empty(); }
    /// litehtml is parsing the master sheet (trusted_styles).
    bool m_trusted = false;
};

} // namespace wr
