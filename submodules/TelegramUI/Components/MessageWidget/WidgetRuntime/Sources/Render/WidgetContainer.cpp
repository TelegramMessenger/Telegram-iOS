#include "Sources/Render/WidgetContainer.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <iterator>
#include <memory>
#include <optional>
#include <string>
#include <unordered_set>
#include <utility>

#include <litehtml.h>

#include "Sources/Host/CSSPolicy.h"
#include "Sources/Host/ICU.h"
#include "Sources/Render/Bidi.h"
#include "Sources/Render/DataUrl.h"
#include "Sources/Render/LayerTree.h"

namespace wr {

namespace {

void appendUnsigned(std::string& key, uint64_t value) {
    char text[24];
    std::snprintf(text, sizeof(text), "%llx,", static_cast<unsigned long long>(value));
    key += text;
}

void appendInt(std::string& key, long long value) {
    char text[24];
    std::snprintf(text, sizeof(text), "%lld,", value);
    key += text;
}

// Exactly: by its bits, so two values compare equal only when they are the same float.
void appendFloat(std::string& key, float value) {
    uint32_t bits = 0;
    std::memcpy(&bits, &value, sizeof(bits));
    appendUnsigned(key, bits);
}

// Length-prefixed, so no string can run into the next field.
void appendString(std::string& key, const std::string& value) {
    appendUnsigned(key, value.size());
    key += value;
    key += ',';
}

void appendColor(std::string& key, const litehtml::web_color& color) {
    appendUnsigned(key, (uint64_t(color.red) << 24) | (uint64_t(color.green) << 16) | (uint64_t(color.blue) << 8) |
                            uint64_t(color.alpha));
    appendUnsigned(key, color.is_current_color ? 1 : 0);
}

void appendLength(std::string& key, const litehtml::css_length& length) {
    appendUnsigned(key, length.is_predefined() ? 1 : 0);
    appendInt(key, length.predef());
    appendFloat(key, length.val());
    appendInt(key, static_cast<long long>(length.units()));
    // A calc's val() is its value at a zero percentage base, so its tree is the key (twidget edit 48), as
    // calc_node::to_string prints it: terms equal to six significant digits share a font.
    appendString(key, length.is_calc() ? length.to_string() : std::string());
}

// The font cache's key: every field of the description, exactly (a calc length as its printed tree, below).
// litehtml's own font_description::hash() is not used because it leaves some out (a colour's current-color flag, a
// transparent shadow's geometry); with every field, a cached font is always one the host made from an equal
// description, whatever earlier builds asked for.
std::string fontKey(const litehtml::font_description& d) {
    std::string key;
    appendString(key, d.family);
    appendFloat(key, d.size.value());
    appendInt(key, static_cast<long long>(d.style));
    appendInt(key, d.weight);
    appendInt(key, d.decoration_line);
    appendLength(key, d.decoration_thickness);
    appendInt(key, static_cast<long long>(d.decoration_style));
    appendColor(key, d.decoration_color);
    appendString(key, d.emphasis_style);
    appendColor(key, d.emphasis_color);
    appendInt(key, d.emphasis_position);
    appendFloat(key, d.letter_spacing);
    appendInt(key, d.smoothing);
    appendFloat(key, d.shadow_x);
    appendFloat(key, d.shadow_y);
    appendFloat(key, d.shadow_blur);
    appendColor(key, d.shadow_color);
    appendUnsigned(key, d.extra_shadows.size());
    for (const auto& shadow : d.extra_shadows) {
        appendFloat(key, shadow.x);
        appendFloat(key, shadow.y);
        appendFloat(key, shadow.blur);
        appendColor(key, shadow.color);
    }
    appendUnsigned(key, d.tabular_nums ? 1 : 0);
    return key;
}

litehtml::pixel_t px(double value) {
    return litehtml::pixel_t(static_cast<float>(value));
}

// Bounds (LayerTree.h, PaintItem::bounds).

litehtml::position grown(const litehtml::position& rect, float by) {
    return litehtml::position(rect.x.value() - by, rect.y.value() - by, rect.width.value() + 2 * by,
                              rect.height.value() + 2 * by);
}

// Ruling E5: the bounds are LHContainer's own dirty allowances, since M1d's renderer is LHContainer's drawing code.

// LHContainer's text shadow clamps and cap (LHContainer.mm:718-721, applied in create_font, LHContainer.mm:1605-1617).
constexpr float kMaxTextShadowBlur = 200;
constexpr float kMaxTextShadowOffset = 400;
constexpr size_t kMaxTextShadows = 8;

// LHContainer::draw_text (LHContainer.mm:2260-2266): pos grown on every side by max(4, height / 2), plus the widest
// shadow's 2·blur + max(|x|, |y|), over the shadows as its create_font keeps them (the primary one when it is not
// transparent, then the extra ones, at most 8, each clamped). Empty text draws nothing.
litehtml::position textBounds(const litehtml::position& pos, const litehtml::font_description& font, bool empty) {
    if (empty) {
        return {};
    }
    auto offset = [](float v) { return std::clamp(v, -kMaxTextShadowOffset, kMaxTextShadowOffset); };
    auto blur = [](float v) { return std::clamp(v, 0.0f, kMaxTextShadowBlur); };
    float shadowReach = 0;
    size_t shadows = 0;
    auto add = [&](float x, float y, float b) {
        shadowReach = std::max(shadowReach, blur(b) * 2 + std::max(std::fabs(offset(x)), std::fabs(offset(y))));
        shadows++;
    };
    if (font.shadow_color.alpha != 0) {
        add(font.shadow_x, font.shadow_y, font.shadow_blur);
    }
    for (const auto& extra : font.extra_shadows) {
        if (shadows >= kMaxTextShadows) {
            break;
        }
        add(extra.x, extra.y, extra.blur);
    }
    const float slack = std::max(4.0f, pos.height.value() / 2) + shadowReach;
    return grown(pos, slack);
}

// LHContainer::draw_box_shadow (LHContainer.mm:3891-3894): nothing for a transparent shadow; an inset one, its box; an
// outer one, its box grown by blur + |spread| + max(|x|, |y|) + 2.
litehtml::position shadowBounds(const litehtml::position& box, const litehtml::shadow_paint& shadow) {
    if (shadow.color.alpha == 0) {
        return {};
    }
    if (shadow.inset) {
        return box;
    }
    const float reach = shadow.blur.value() + std::fabs(shadow.spread.value()) +
                        std::max(std::fabs(shadow.x.value()), std::fabs(shadow.y.value())) + 2;
    return grown(box, reach);
}

// The bounds of a path's points on its curves, as CGPathGetPathBoundingBox gives them for the path LHContainer's
// CreateVectorPath builds (LHContainer.mm:4038-4076): ops consume 2, 4 (quad), 6 (cubic) or 0 (close) numbers, and
// the walk stops at the first op that runs out; a segment draws only after a move; curves count their extrema, not
// their control points. nullopt for a path with no point (CGRectNull).
std::optional<litehtml::position> curveBounds(const litehtml::vector_path& path) {
    const std::vector<float>& p = path.points;
    double minX = 0, minY = 0, maxX = 0, maxY = 0;
    bool any = false;
    auto include = [&](double x, double y) {
        if (!any) {
            minX = maxX = x;
            minY = maxY = y;
            any = true;
            return;
        }
        minX = std::min(minX, x);
        maxX = std::max(maxX, x);
        minY = std::min(minY, y);
        maxY = std::max(maxY, y);
    };
    // The roots in (0, 1) of a·t² + b·t + c.
    auto roots = [](double a, double b, double c, double out[2]) {
        int count = 0;
        if (std::fabs(a) < 1e-12) {
            if (std::fabs(b) > 1e-12) {
                out[count++] = -c / b;
            }
        } else {
            const double d = b * b - 4 * a * c;
            if (d >= 0) {
                const double s = std::sqrt(d);
                out[count++] = (-b + s) / (2 * a);
                out[count++] = (-b - s) / (2 * a);
            }
        }
        int kept = 0;
        for (int i = 0; i < count; i++) {
            if (out[i] > 0 && out[i] < 1) {
                out[kept++] = out[i];
            }
        }
        return kept;
    };
    double cx = 0, cy = 0;   // the current point
    bool open = false;
    size_t i = 0;
    for (auto op : path.ops) {
        const size_t need = op == litehtml::vector_path::cubic ? 6 : op == litehtml::vector_path::quad ? 4
                            : op == litehtml::vector_path::close ? 0 : 2;
        if (i + need > p.size()) {
            break;
        }
        switch (op) {
        case litehtml::vector_path::move:
            cx = p[i];
            cy = p[i + 1];
            include(cx, cy);
            open = true;
            break;
        case litehtml::vector_path::line:
            if (open) {
                cx = p[i];
                cy = p[i + 1];
                include(cx, cy);
            }
            break;
        case litehtml::vector_path::quad:
            if (open) {
                const double x1 = p[i], y1 = p[i + 1], x2 = p[i + 2], y2 = p[i + 3];
                include(x2, y2);
                for (int axis = 0; axis < 2; axis++) {
                    const double a0 = axis ? cy : cx, a1 = axis ? y1 : x1, a2 = axis ? y2 : x2;
                    double t[2];
                    for (int k = roots(0, 2 * (a0 - 2 * a1 + a2), 2 * (a1 - a0), t), j = 0; j < k; j++) {
                        const double u = 1 - t[j];
                        include(u * u * cx + 2 * u * t[j] * x1 + t[j] * t[j] * x2,
                                u * u * cy + 2 * u * t[j] * y1 + t[j] * t[j] * y2);
                    }
                }
                cx = x2;
                cy = y2;
            }
            break;
        case litehtml::vector_path::cubic:
            if (open) {
                const double x1 = p[i], y1 = p[i + 1], x2 = p[i + 2], y2 = p[i + 3], x3 = p[i + 4], y3 = p[i + 5];
                include(x3, y3);
                for (int axis = 0; axis < 2; axis++) {
                    const double a0 = axis ? cy : cx, a1 = axis ? y1 : x1, a2 = axis ? y2 : x2, a3 = axis ? y3 : x3;
                    double t[2];
                    const int k = roots(3 * (-a0 + 3 * a1 - 3 * a2 + a3), 6 * (a0 - 2 * a1 + a2), 3 * (a1 - a0), t);
                    for (int j = 0; j < k; j++) {
                        const double u = 1 - t[j];
                        const double w0 = u * u * u, w1 = 3 * u * u * t[j], w2 = 3 * u * t[j] * t[j],
                                     w3 = t[j] * t[j] * t[j];
                        include(w0 * cx + w1 * x1 + w2 * x2 + w3 * x3, w0 * cy + w1 * y1 + w2 * y2 + w3 * y3);
                    }
                }
                cx = x3;
                cy = y3;
            }
            break;
        case litehtml::vector_path::close:
            break;
        }
        i += need;
    }
    if (!any) {
        return std::nullopt;
    }
    return litehtml::position(float(minX), float(minY), float(maxX - minX), float(maxY - minY));
}

// LHContainer::draw_path (LHContainer.mm:4154-4163): nothing unless filled or stroked, or for an empty path; else the
// path's bounds grown by stroke_width × max(miter_limit, 1) / 2 + 1 when stroked, by 1 (antialiasing) when not.
litehtml::position pathBounds(const litehtml::vector_path& path) {
    const std::optional<litehtml::position> box = curveBounds(path);
    if ((!path.fill && !path.stroke) || !box) {
        return {};
    }
    const float reach = path.stroke ? path.stroke_width * std::max(path.miter_limit, 1.0f) / 2 + 1 : 1;
    return grown(*box, reach);
}

} // namespace

WidgetContainer::WidgetContainer(RenderHost& host, RenderOptions options)
    : m_host(host), m_options(std::move(options)), m_defaultFontName(host.defaultFontName()) {}

// The caches release their references; fonts and images the host made stay alive while a handle or a published layer
// tree holds them.
WidgetContainer::~WidgetContainer() = default;

std::shared_ptr<const LayerTree> WidgetContainer::record(litehtml::document& document) {
    const double width = double(document.width().value());
    const double height = double(document.height().value());
    Layer root;
    root.kind = Layer::Kind::Root;
    root.box = litehtml::position(0, 0, document.width(), document.height());
    // The open layers are this call's alone; they are forgotten however draw() ends.
    struct Closing {
        std::vector<Layer*>& open;
        ~Closing() { open.clear(); }
    } closing{m_open};
    m_open.assign(1, &root);
    document.draw(reinterpret_cast<litehtml::uint_ptr>(&root), litehtml::pixel_t(0), litehtml::pixel_t(0), nullptr);
    return std::make_shared<const LayerTree>(width, height, std::move(root), canvasColor(document));
}

// The recorder's bounds rules (LayerTree.h, PaintItem::bounds), from an item's payload; each draw_* below computes the
// same through the same functions.
litehtml::position paintBounds(const PaintItem& item, const Layer& enclosing) {
    switch (item.kind) {
    case PaintItem::Kind::Text: {
        const auto& text = std::get<TextItem>(item.payload);
        return text.description ? textBounds(text.pos, *text.description, text.text.empty()) : litehtml::position();
    }
    case PaintItem::Kind::ListMarker:
        return std::get<ListMarkerItem>(item.payload).marker.pos;
    case PaintItem::Kind::Image:
        return std::get<ImageItem>(item.payload).layer.clip_box;
    case PaintItem::Kind::SolidFill:
        return std::get<FillItem>(item.payload).layer.clip_box;
    case PaintItem::Kind::LinearGradient:
        return std::get<LinearGradientItem>(item.payload).layer.clip_box;
    case PaintItem::Kind::RadialGradient:
        return std::get<RadialGradientItem>(item.payload).layer.clip_box;
    case PaintItem::Kind::ConicGradient:
        return std::get<ConicGradientItem>(item.payload).layer.clip_box;
    case PaintItem::Kind::Borders:
        return std::get<BordersItem>(item.payload).drawPos;
    case PaintItem::Kind::BoxShadow: {
        const auto& shadow = std::get<BoxShadowItem>(item.payload);
        return shadowBounds(shadow.box, shadow.shadow);
    }
    case PaintItem::Kind::Path:
        return pathBounds(std::get<PathItem>(item.payload).path);
    case PaintItem::Kind::Backdrop:
        return enclosing.kind == Layer::Kind::Filter ? std::get<BackdropItem>(item.payload).bounds : layerBounds(enclosing);
    case PaintItem::Kind::SetClip:
        return std::get<ClipItem>(item.payload).pos;
    case PaintItem::Kind::SetClipPath:
        return curveBounds(std::get<ClipPathItem>(item.payload).path).value_or(litehtml::position());
    case PaintItem::Kind::DelClip:
    case PaintItem::Kind::SuspendClips:
    case PaintItem::Kind::ResumeClips:
        return litehtml::position();
    }
    return litehtml::position();
}

void WidgetContainer::beginWalk(WalkListener& listener) {
    m_walk = &listener;
    m_open.clear();
}

void WidgetContainer::endWalk() {
    m_walk = nullptr;
    m_open.clear();
}

void WidgetContainer::capture(Layer& target, const std::function<void()>& paint) {
    // The capture is this call's alone; the walk's state comes back however the paint ends.
    struct Restore {
        std::vector<Layer*>& open;
        std::vector<Layer*> saved;
        ~Restore() { open.swap(saved); }
    } restore{m_open, {}};
    restore.saved.swap(m_open);
    m_open.assign(1, &target);
    paint();
}

void WidgetContainer::append(PaintItem item) {
    if (Layer* layer = openLayer()) {
        layer->entries.emplace_back(std::move(item));
    }
}

void WidgetContainer::setOptions(RenderOptions options) {
    m_options = std::move(options);
}

void WidgetContainer::beginBuild() {
    m_limitsHit.clear();
}

void WidgetContainer::prune(litehtml::document& document) {
    std::unordered_set<std::string> fonts;
    std::unordered_set<std::string_view> images;
    std::vector<const litehtml::element*> stack;
    if (document.root()) {
        stack.push_back(document.root().get());
    }
    while (!stack.empty()) {
        const litehtml::element* el = stack.back();
        stack.pop_back();
        const litehtml::css_properties& css = el->css();
        if (const FontHandle* handle = handleOf(css.get_font()); handle && handle->description) {
            fonts.insert(fontKey(*handle->description));
        }
        for (const litehtml::image& image : css.get_bg().m_image) {
            if (image.type == litehtml::image::type_url && !image.url.empty()) {
                images.insert(image.url);
            }
        }
        if (!css.get_list_style_image().empty()) {
            images.insert(css.get_list_style_image());
        }
        if (el->tag() == litehtml::_img_) {
            if (const char* src = el->get_attr("src")) {
                images.insert(src);
            }
        }
        for (const litehtml::element::ptr& child : el->children()) {
            stack.push_back(child.get());
        }
    }
    std::erase_if(m_fonts, [&fonts](const auto& entry) { return fonts.count(entry.first) == 0; });
    std::erase_if(m_images, [&images](const auto& entry) { return images.count(entry.first) == 0; });
}

const WidgetContainer::FontHandle* WidgetContainer::handleOf(litehtml::uint_ptr hFont) {
    return reinterpret_cast<const FontHandle*>(hFont);
}

const std::shared_ptr<const HostFont>& WidgetContainer::fontOf(litehtml::uint_ptr hFont) {
    static const std::shared_ptr<const HostFont> none;
    const FontHandle* handle = handleOf(hFont);
    return handle ? handle->font : none;
}

const WidgetContainer::CachedImage& WidgetContainer::decide(std::string_view src) {
    auto found = m_images.find(src);
    if (found == m_images.end()) {
        CachedImage entry;
        // Only a data: URL of profile 1's image types reaches the host, and only as its decoded bytes, and the
        // placeholder (V4 plan, Task 6). Every scheme, a relative URL, a fragment, icon: and sf:, another image type
        // (SVG, BMP, ICO, AVIF, ...) and a data: URL that does not parse are refused.
        std::optional<DataUrl> data;
        if (src == kPlaceholderURL) {
            const std::string_view svg = placeholderSVG();
            data = DataUrl{"image/svg+xml", std::vector<uint8_t>(svg.begin(), svg.end())};
        } else {
            switch (css::policy::imageSource(src)) {
            case css::policy::ImageSource::Kept:
                data = parseDataUrl(src);
                break;
            case css::policy::ImageSource::Broken:
                // Bytes of none of the profile's formats (widget-sandbox v0.3.0): no decoder takes them, whatever
                // ImageIO would sniff.
                entry.load = Load::Undecodable;
                break;
            case css::policy::ImageSource::Refused:
                break;
            }
        }
        if (data) {
            std::optional<DecodedImage> decoded = m_host.decodeImage(data->mimeType, data->bytes);
            if (decoded) {
                entry.load = Load::Decoded;
                entry.image = std::move(*decoded);
            } else {
                entry.load = Load::Undecodable;
            }
        }
        found = m_images.emplace(std::string(src), std::move(entry)).first;
    }
    return found->second;
}

// Layout.

litehtml::uint_ptr WidgetContainer::create_font(const litehtml::font_description& requested, const litehtml::document*,
                                                litehtml::font_metrics* fm) {
    // The backstop of the profile's font rule (V4 plan, Task 3b): a family no declaration hook saw (an SVG font
    // attribute, a family a var() carried) is reduced to the profile's generic families before the host resolves it.
    litehtml::font_description descr = requested;
    descr.family = css::policy::reduceFontFamilyText(requested.family);
    std::string key = fontKey(descr);
    auto found = m_fonts.find(key);
    if (found == m_fonts.end()) {
        CachedFont entry;
        entry.font = m_host.createFont(descr, entry.metrics);
        entry.description = std::make_shared<const litehtml::font_description>(descr);
        found = m_fonts.emplace(std::move(key), std::move(entry)).first;
    }
    if (fm) {
        *fm = found->second.metrics;
    }
    // Never 0, which litehtml reads as "no font", even if the host made none.
    return reinterpret_cast<litehtml::uint_ptr>(new FontHandle{found->second.font, found->second.description});
}

std::vector<float> WidgetContainer::caretOffsets(litehtml::uint_ptr hFont, std::string_view utf8) const {
    const std::shared_ptr<const HostFont>& font = fontOf(hFont);
    return font ? m_host.caretOffsets(*font, utf8) : std::vector<float>();
}

void WidgetContainer::delete_font(litehtml::uint_ptr hFont) {
    delete reinterpret_cast<FontHandle*>(hFont);
}

litehtml::pixel_t WidgetContainer::text_width(const char* text, litehtml::uint_ptr hFont) {
    const std::shared_ptr<const HostFont>& font = fontOf(hFont);
    if (!font || !text) {
        return 0;
    }
    return px(m_host.textWidth(*font, text));
}

bool WidgetContainer::bidi_levels(const std::vector<std::string>& runs, bool rtl, std::vector<uint8_t>& levels) {
    // The line's text in UTF-16, each run sampled at its first strong character (L, R or AL), else at its first unit
    // (review minors, Task 5: a run can start with a neutral, whose level is its neighbours'); a malformed byte reads as
    // U+FFFD.
    std::u16string text;
    std::vector<size_t> starts;
    starts.reserve(runs.size());
    for (const std::string& run : runs) {
        starts.push_back(text.size());
        bool strongSeen = false;
        for (size_t i = 0; i < run.size();) {
            UChar32 c = 0;
            int32_t offset = int32_t(i);
            U8_NEXT_OR_FFFD(reinterpret_cast<const uint8_t*>(run.data()), offset, int32_t(run.size()), c);
            i = size_t(offset);
            if (!strongSeen) {
                const UCharDirection direction = u_charDirection(c);
                if (direction == U_LEFT_TO_RIGHT || direction == U_RIGHT_TO_LEFT || direction == U_RIGHT_TO_LEFT_ARABIC) {
                    starts.back() = text.size();
                    strongSeen = true;
                }
            }
            if (c > 0xFFFF) {
                text.push_back(char16_t(U16_LEAD(c)));
                text.push_back(char16_t(U16_TRAIL(c)));
            } else {
                text.push_back(char16_t(c));
            }
        }
        if (run.empty()) {
            text.push_back(u'\uFFFC');
        }
    }
    const std::vector<uint8_t> resolved = bidi::levels(text, rtl ? 1 : 0);
    levels.clear();
    for (size_t start : starts) {
        levels.push_back(resolved[start]);
    }
    return true;
}

std::shared_ptr<litehtml::text_breaker> WidgetContainer::create_text_breaker(const std::string& text,
                                                                             litehtml::uint_ptr hFont) {
    const std::shared_ptr<const HostFont>& font = fontOf(hFont);
    return font ? m_host.createTextBreaker(*font, text) : nullptr;
}

void WidgetContainer::transform_text(std::string& text, litehtml::text_transform tt) {
    m_host.transformText(text, tt);
}

litehtml::pixel_t WidgetContainer::pt_to_px(float pt) const {
    return litehtml::pixel_t(pt * 96.0f / 72.0f);
}

litehtml::pixel_t WidgetContainer::get_default_font_size() const {
    return px(m_host.defaultFontSize());
}

const char* WidgetContainer::get_default_font_name() const {
    return m_defaultFontName.c_str();
}

void WidgetContainer::get_viewport(litehtml::position& viewport) const {
    viewport = litehtml::position(0, 0, px(m_options.width), px(m_options.viewportHeight));
}

// LHContainer's (LHContainer.mm:4654-4666), and the color scheme (twidget edit 13).
void WidgetContainer::get_media_features(litehtml::media_features& media) const {
    media.type = litehtml::media_type_screen;
    media.width = px(m_options.width);
    media.height = px(m_options.viewportHeight);
    media.device_width = 1440;
    media.device_height = 900;
    media.color = 8;
    media.monochrome = 0;
    media.color_index = 256;
    media.resolution = 96;
    media.color_scheme = m_options.theme == Theme::Dark ? 1 : 0;
    media.reduced_motion = m_options.reducedMotion ? 1 : 0;
}

// Profile 1 (V4 plan, Task 3b): litehtml asks while it parses; the policy is pure and its walks are bounded by the text
// the builder handed litehtml.

bool WidgetContainer::sanitize_at_rule(const std::string& name) {
    return m_trusted || css::policy::atRuleKept(name);
}

bool WidgetContainer::profile_declaration(std::string& name, litehtml::css_token_vector& value, bool&) {
    // -lh-anim marks the animations origin's block (twidget edit 27): the runtime's own.
    if (m_trusted || name == "-lh-anim") {
        return true;
    }
    css::policy::Judged judged = css::policy::declaration(name, value);
    if (judged.verdict == css::policy::Verdict::Drop) {
        return false;
    }
    if (judged.verdict != css::policy::Verdict::Keep) {
        value = std::move(judged.value);
    }
    return true;
}

bool WidgetContainer::profile_substituted(const std::string& name, litehtml::css_token_vector& value) {
    // Closes the reference's var() bypass (plan decision 4): the value is judged once substituted, as if written so. A
    // master-sheet value (the UA button's font var()) is kept as the policy keeps it: generic families only.
    css::policy::Judged judged = css::policy::declaration(name, value);
    if (judged.verdict == css::policy::Verdict::Drop) {
        return false;
    }
    if (judged.verdict != css::policy::Verdict::Keep) {
        value = std::move(judged.value);
    }
    return true;
}

void WidgetContainer::sanitize_selector_list(std::vector<litehtml::css_token_vector>& groups) {
    if (m_trusted) {
        return;
    }
    std::vector<litehtml::css_token_vector> kept;
    kept.reserve(groups.size());
    for (litehtml::css_token_vector& group : groups) {
        css::policy::Judged judged = css::policy::selector(group);
        if (judged.verdict == css::policy::Verdict::Drop) {
            continue;
        }
        kept.push_back(judged.verdict == css::policy::Verdict::Keep ? std::move(group) : std::move(judged.value));
    }
    groups = std::move(kept);
}

bool WidgetContainer::sanitize_media_query(const litehtml::css_token_vector& prelude) {
    return m_trusted || css::policy::mediaQueryInProfile(prelude);
}

int WidgetContainer::evaluate_supports(const litehtml::css_token_vector& condition) {
    return m_trusted ? -1 : int(css::policy::supportsCondition(condition));
}

void WidgetContainer::get_language(std::string& language, std::string& culture) const {
    language = "en";
    culture.clear();
}

litehtml::element::ptr WidgetContainer::create_element(const char*, const litehtml::string_map&,
                                                       const std::shared_ptr<litehtml::document>&) {
    return nullptr;
}

bool WidgetContainer::point_in_clip_path(const litehtml::vector_path& path, litehtml::pixel_t x, litehtml::pixel_t y) {
    return m_host.pathContains(path, double(x.value()), double(y.value()));
}

// litehtml may report a limit on every refusal (document.cpp, telegram_external.cpp), so each kind is kept once.
void WidgetContainer::sanitizer_limit(const char* what) {
    if (!what) {
        return;
    }
    if (std::find(m_limitsHit.begin(), m_limitsHit.end(), what) == m_limitsHit.end()) {
        m_limitsHit.emplace_back(what);
    }
}

std::optional<DecodedImage> WidgetContainer::decodeImageUncached(std::string_view src) {
    if (src == kPlaceholderURL) {
        const std::string_view svg = placeholderSVG();
        return m_host.decodeImage("image/svg+xml", std::span<const uint8_t>(reinterpret_cast<const uint8_t*>(svg.data()), svg.size()));
    }
    if (!css::policy::imageSourceKept(src)) {
        return std::nullopt;
    }
    std::optional<DataUrl> data = parseDataUrl(src);
    if (!data) {
        return std::nullopt;
    }
    return m_host.decodeImage(data->mimeType, data->bytes);
}

std::string_view WidgetContainer::placeholderSVG() {
    return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"48\" height=\"48\" viewBox=\"0 0 48 48\"><rect width=\"48\" "
           "height=\"48\" fill=\"#8882\"/><path d=\"M8 36l10-12 8 9 6-7 8 10z\" fill=\"#8886\"/><circle cx=\"33\" "
           "cy=\"15\" r=\"4\" fill=\"#8886\"/></svg>";
}

std::optional<DecodedImage> WidgetContainer::decodedByLayout(std::string_view src) const {
    auto found = m_images.find(src);
    if (found == m_images.end() || found->second.load != Load::Decoded) {
        return std::nullopt;
    }
    return found->second.image;
}

std::string WidgetContainer::canvasURL(const CanvasURL& canvas) {
    return "twcanvas:" + std::to_string(canvas.serial) + ":" + std::to_string(canvas.width) + ":" + std::to_string(canvas.height);
}

std::optional<WidgetContainer::CanvasURL> WidgetContainer::parseCanvasURL(std::string_view url) {
    constexpr std::string_view kScheme = "twcanvas:";
    if (url.substr(0, kScheme.size()) != kScheme) {
        return std::nullopt;
    }
    url.remove_prefix(kScheme.size());
    uint64_t parts[3] = {};
    for (int i = 0; i < 3; i++) {
        size_t digits = 0;
        while (digits < url.size() && digits < 20 && url[digits] >= '0' && url[digits] <= '9') {
            parts[i] = parts[i] * 10 + uint64_t(url[digits] - '0');
            digits++;
        }
        if (digits == 0 || (i < 2 && (digits >= url.size() || url[digits] != ':')) || (i == 2 && digits != url.size())) {
            return std::nullopt;
        }
        url.remove_prefix(i < 2 ? digits + 1 : digits);
    }
    if (parts[1] > UINT32_MAX || parts[2] > UINT32_MAX) {
        return std::nullopt;
    }
    return CanvasURL{parts[0], uint32_t(parts[1]), uint32_t(parts[2])};
}

// Loads. An empty source asks for nothing and is not counted, as LHContainer's refuse_request does not.

void WidgetContainer::load_image(const char* src, const char*, bool) {
    if (!src || !*src || parseCanvasURL(src)) {
        return;
    }
    if (decide(src).load == Load::Refused) {
        m_refusedLoads++;
    }
}

void WidgetContainer::get_image_size(const char* src, const char*, litehtml::size& sz) {
    sz.width = 0;
    sz.height = 0;
    if (!src || !*src) {
        return;
    }
    if (std::optional<CanvasURL> canvas = parseCanvasURL(src)) {
        sz.width = px(double(canvas->width));
        sz.height = px(double(canvas->height));
        return;
    }
    const CachedImage& image = decide(src);
    if (image.load == Load::Refused) {
        m_refusedLoads++;
    } else if (image.load == Load::Decoded) {
        sz.width = px(image.image.width);
        sz.height = px(image.image.height);
    }
}

// No stylesheet loads: an @import or a <link rel=stylesheet> gets no text.
void WidgetContainer::import_css(std::string& text, const std::string&, std::string&) {
    text.clear();
    m_refusedLoads++;
}

// Any other <link> (and a stylesheet one, once import_css gave it nothing).
void WidgetContainer::link(const std::shared_ptr<litehtml::document>&, const litehtml::element::ptr&) {
    m_refusedLoads++;
}

// Inert.

void WidgetContainer::on_anchor_click(const char*, const litehtml::element::ptr&) {}

bool WidgetContainer::on_element_click(const litehtml::element::ptr&) {
    return false;
}

void WidgetContainer::on_mouse_event(const litehtml::element::ptr&, litehtml::mouse_event) {}

void WidgetContainer::set_cursor(const char*) {}

void WidgetContainer::set_caption(const char*) {}

void WidgetContainer::set_base_url(const char*) {}

// Paint: one item per call, appended to the innermost open layer (LayerTree.h).

void WidgetContainer::draw_text(litehtml::uint_ptr, const char* text, litehtml::uint_ptr hFont, litehtml::web_color color,
                                const litehtml::position& pos) {
    if (walking()) {
        m_walk->walkStray();
        return;
    }
    const FontHandle* handle = handleOf(hFont);
    if (!openLayer() || !text || !handle || !handle->font) {
        return;
    }
    // Shaped now, by the font that measured it (Ruling 19).
    TextItem item;
    item.text = text;
    item.font = handle->font;
    item.description = handle->description;
    item.shaped = m_host.shape(*handle->font, item.text);
    item.color = color;
    item.pos = pos;
    const litehtml::position bounds = textBounds(pos, *item.description, item.text.empty());
    append({PaintItem::Kind::Text, bounds, std::move(item)});
}

void WidgetContainer::draw_list_marker(litehtml::uint_ptr, const litehtml::list_marker& marker) {
    if (walking()) {
        m_walk->walkStray();
        return;
    }
    // Field by field: `image` (the URL, possibly a long data: URL) is never copied, not even into a buffer later
    // cleared, and the handles are not kept.
    ListMarkerItem item;
    item.marker.baseurl = nullptr;
    item.marker.marker_type = marker.marker_type;
    item.marker.color = marker.color;
    item.marker.pos = marker.pos;
    item.marker.index = marker.index;
    item.marker.font = 0;
    item.font = fontOf(marker.font);
    // An image marker is a request for its URL, decided and counted as any other (LHContainer counts it here too).
    if (!marker.image.empty()) {
        const CachedImage& image = decide(marker.image);
        if (image.load == Load::Refused) {
            m_refusedLoads++;
        } else if (image.load == Load::Decoded) {
            item.image = image.image;
        }
    }
    append({PaintItem::Kind::ListMarker, marker.pos, std::move(item)});
}

// A refused URL is counted, as every refused call is, and records nothing; so does one the host could not decode.
void WidgetContainer::draw_image(litehtml::uint_ptr, const litehtml::background_layer& layer, const std::string& url,
                                 const std::string&) {
    if (walking()) {
        m_walk->walkStray();
        return;
    }
    if (url.empty()) {
        return;
    }
    if (std::optional<CanvasURL> canvas = parseCanvasURL(url)) {
        std::optional<DecodedImage> pixels = m_canvasSource ? m_canvasSource(canvas->serial) : std::nullopt;
        if (pixels) {
            append({PaintItem::Kind::Image, layer.clip_box, ImageItem{layer, std::move(*pixels)}});
        }
        return;
    }
    const CachedImage& image = decide(url);
    if (image.load == Load::Refused) {
        m_refusedLoads++;
        return;
    }
    if (image.load != Load::Decoded) {
        return;
    }
    append({PaintItem::Kind::Image, layer.clip_box, ImageItem{layer, image.image}});
}

void WidgetContainer::draw_solid_fill(litehtml::uint_ptr, const litehtml::background_layer& layer,
                                      const litehtml::web_color& color) {
    if (walking()) {
        m_walk->walkStray();
        return;
    }
    append({PaintItem::Kind::SolidFill, layer.clip_box, FillItem{layer, color}});
}

void WidgetContainer::draw_linear_gradient(litehtml::uint_ptr, const litehtml::background_layer& layer,
                                           const litehtml::background_layer::linear_gradient& gradient) {
    if (walking()) {
        m_walk->walkStray();
        return;
    }
    append({PaintItem::Kind::LinearGradient, layer.clip_box, LinearGradientItem{layer, gradient}});
}

void WidgetContainer::draw_radial_gradient(litehtml::uint_ptr, const litehtml::background_layer& layer,
                                           const litehtml::background_layer::radial_gradient& gradient) {
    if (walking()) {
        m_walk->walkStray();
        return;
    }
    append({PaintItem::Kind::RadialGradient, layer.clip_box, RadialGradientItem{layer, gradient}});
}

void WidgetContainer::draw_conic_gradient(litehtml::uint_ptr, const litehtml::background_layer& layer,
                                          const litehtml::background_layer::conic_gradient& gradient) {
    if (walking()) {
        m_walk->walkStray();
        return;
    }
    append({PaintItem::Kind::ConicGradient, layer.clip_box, ConicGradientItem{layer, gradient}});
}

void WidgetContainer::draw_borders(litehtml::uint_ptr, const litehtml::borders& borders,
                                   const litehtml::position& draw_pos, bool root) {
    if (walking()) {
        m_walk->walkStray();
        return;
    }
    append({PaintItem::Kind::Borders, draw_pos, BordersItem{borders, draw_pos, root}});
}

void WidgetContainer::draw_box_shadow(litehtml::uint_ptr, const litehtml::position& box,
                                      const litehtml::border_radiuses& radius, const litehtml::shadow_paint& shadow) {
    if (walking()) {
        m_walk->walkStray();
        return;
    }
    append({PaintItem::Kind::BoxShadow, shadowBounds(box, shadow), BoxShadowItem{box, radius, shadow}});
}

void WidgetContainer::draw_path(litehtml::uint_ptr, const litehtml::vector_path& path) {
    if (walking()) {
        m_walk->walkStray();
        return;
    }
    append({PaintItem::Kind::Path, pathBounds(path), PathItem{path}});
}

// filter_paint's steps point into the element's style and its owner is the element: the steps are copied, the owner
// dropped. A backdrop is bounded by the layer it is drawn in.
void WidgetContainer::draw_backdrop(litehtml::uint_ptr, const litehtml::filter_paint& filter) {
    if (walking()) {
        m_walk->walkBackdrop(filter);
        return;
    }
    Layer* layer = openLayer();
    if (!layer) {
        return;
    }
    BackdropItem item;
    if (filter.steps) {
        item.steps = *filter.steps;
    }
    item.bounds = filter.bounds;
    item.box = filter.box;
    item.radius = filter.radius;
    const litehtml::position bounds = layer->kind == Layer::Kind::Filter ? filter.bounds : layerBounds(*layer);
    append({PaintItem::Kind::Backdrop, bounds, std::move(item)});
}

void WidgetContainer::set_clip(const litehtml::position& pos, const litehtml::border_radiuses& bdr_radius) {
    if (walking()) {
        m_walk->walkSetClip(pos, bdr_radius);
        return;
    }
    append({PaintItem::Kind::SetClip, pos, ClipItem{pos, bdr_radius}});
}

void WidgetContainer::del_clip() {
    if (walking()) {
        m_walk->walkDelClip();
        return;
    }
    append({PaintItem::Kind::DelClip, litehtml::position(), std::monostate()});
}

void WidgetContainer::suspend_clips() {
    if (walking()) {
        m_walk->walkSuspendClips();
        return;
    }
    append({PaintItem::Kind::SuspendClips, litehtml::position(), std::monostate()});
}

void WidgetContainer::resume_clips() {
    if (walking()) {
        m_walk->walkResumeClips();
        return;
    }
    append({PaintItem::Kind::ResumeClips, litehtml::position(), std::monostate()});
}

void WidgetContainer::set_clip_path(const litehtml::vector_path& path) {
    if (walking()) {
        m_walk->walkClipPath(path);
        return;
    }
    // LHContainer::set_clip_path (LHContainer.mm:2506-2509): the path's bounds, no allowance; CGRectNull is zero.
    append({PaintItem::Kind::SetClipPath, curveBounds(path).value_or(litehtml::position()), ClipPathItem{path}});
}

void WidgetContainer::begin_group(litehtml::uint_ptr, const litehtml::paint_group& group) {
    if (walking()) {
        m_walk->walkBeginGroup(group);
        return;
    }
    Layer* parent = openLayer();
    if (!parent) {
        return;
    }
    auto layer = std::make_unique<Layer>();
    layer->kind = Layer::Kind::Group;
    layer->group = group;
    Layer* opened = layer.get();
    parent->entries.emplace_back(std::move(layer));
    m_open.push_back(opened);
}

// Closes the innermost open layer only when it is a Group: an unbalanced end_group never closes a Filter or an
// Isolated layer whose paint is still running, nor the root.
void WidgetContainer::end_group(litehtml::uint_ptr) {
    if (walking()) {
        m_walk->walkEndGroup();
        return;
    }
    if (m_open.size() > 1 && m_open.back()->kind == Layer::Kind::Group) {
        m_open.pop_back();
    }
}

void WidgetContainer::draw_filtered(litehtml::uint_ptr hdc, const litehtml::filter_paint& filter,
                                    const std::function<void(litehtml::uint_ptr)>& paint) {
    if (walking()) {
        m_walk->walkFiltered(filter, [&] { paint(hdc); });
        return;
    }
    Layer* parent = openLayer();
    if (!parent) {
        paint(hdc);
        return;
    }
    auto layer = std::make_unique<Layer>();
    layer->kind = Layer::Kind::Filter;
    if (filter.steps) {
        layer->filter = *filter.steps;
    }
    Layer* opened = layer.get();
    parent->entries.emplace_back(std::move(layer));
    const size_t depth = m_open.size();
    m_open.push_back(opened);
    paint(reinterpret_cast<litehtml::uint_ptr>(opened));
    // Groups the paint left open close with it.
    m_open.resize(depth);
    litehtml::position bounds;
    for (const auto& entry : opened->entries) {
        bounds = unite(bounds, entryBounds(entry));
    }
    opened->box = bounds;
}

void WidgetContainer::draw_isolated(litehtml::uint_ptr hdc, const litehtml::position& box,
                                    const std::function<void(litehtml::uint_ptr)>& paint) {
    if (walking()) {
        m_walk->walkStray();
        paint(hdc);
        return;
    }
    Layer* parent = openLayer();
    if (!parent) {
        paint(hdc);
        return;
    }
    auto layer = std::make_unique<Layer>();
    layer->kind = Layer::Kind::Isolated;
    layer->box = box;
    Layer* opened = layer.get();
    parent->entries.emplace_back(std::move(layer));
    const size_t depth = m_open.size();
    m_open.push_back(opened);
    paint(reinterpret_cast<litehtml::uint_ptr>(opened));
    m_open.resize(depth);
}

bool WidgetContainer::draw_cached(litehtml::uint_ptr, const litehtml::position&, uint64_t,
                                  const std::function<void(litehtml::uint_ptr)>&) {
    return false;
}

} // namespace wr
