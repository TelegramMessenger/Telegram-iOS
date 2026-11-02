#include "Sources/Canvas/CanvasState.h"

#include <algorithm>

#include "Sources/Canvas/CanvasContext2D.h"
#include "Sources/Canvas/CanvasElement.h"
#include "Sources/Canvas/ImageElement.h"
#include "Sources/DOM/DOMState.h"
#include "Sources/Host/HostState.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Runtime/Runtime.h"

namespace wr::canvas {

CanvasState::CanvasState(JSContext* ctx) : m_ctx(ctx), m_dom(DOMState::of(ctx)) {
    m_dom.attributeListeners().push_back(this);
}

CanvasState::~CanvasState() {
    auto& listeners = m_dom.attributeListeners();
    listeners.erase(std::remove(listeners.begin(), listeners.end(), this), listeners.end());
}

CanvasState& CanvasState::of(JSContext* ctx) {
    std::unique_ptr<CanvasState>& slot = HostState::of(ctx).canvasSlot();
    if (!slot) {
        slot = std::make_unique<CanvasState>(ctx);
    }
    return *slot;
}

RenderHost* CanvasState::host() const {
    HostState* state = HostState::find(m_ctx);
    RenderTree* render = state ? state->render() : nullptr;
    return render ? &render->host() : nullptr;
}

std::unique_ptr<Bitmap> CanvasState::allocate(int width, int height) {
    if (width <= 0 || height <= 0 || width > kMaxSide || height > kMaxSide) {
        return nullptr;
    }
    const uint64_t pixels = uint64_t(width) * uint64_t(height);
    if (pixels > kMaxPixels - std::min(*m_used, kMaxPixels)) {
        this->reportLimit("canvas-pixels");
        return nullptr;
    }
    RenderHost* render = this->host();
    std::unique_ptr<HostCanvas> canvas = render ? render->createCanvas(width, height) : nullptr;
    if (!canvas) {
        return nullptr;
    }
    *m_used += pixels;
    return std::make_unique<Bitmap>(std::move(canvas), pixels, m_used);
}

std::optional<CanvasHost::Font> CanvasState::font(const FontValue& value) {
    RenderHost* render = this->host();
    if (!render) {
        return std::nullopt;
    }
    if (render != m_fontHost) {
        m_fonts.clear();
        m_fontHost = render;
    }
    auto found = m_fonts.find(value.serialized);
    if (found != m_fonts.end()) {
        return found->second;
    }
    litehtml::font_metrics metrics;
    std::shared_ptr<const HostFont> made = render->createFont(value.description, metrics);
    if (!made) {
        return std::nullopt;
    }
    if (m_fonts.size() >= kMaxFonts) {
        m_fonts.clear();
    }
    CanvasHost::Font font{std::move(made), double(metrics.ascent.value()), double(metrics.descent.value())};
    m_fonts.emplace(value.serialized, font);
    return font;
}

std::optional<DecodedImage> CanvasState::sharedImage(std::string_view src) {
    const std::pair<size_t, size_t> key{std::hash<std::string_view>()(src), src.size()};
    auto found = m_images.find(key);
    if (found != m_images.end()) {
        if (std::shared_ptr<const HostImage> image = found->second.image.lock()) {
            return DecodedImage{std::move(image), found->second.width, found->second.height};
        }
    }
    HostState* state = HostState::find(m_ctx);
    RenderTree* render = state ? state->render() : nullptr;
    if (!render) {
        return std::nullopt;
    }
    // A rendered <img>'s decode is layout's: shared, not made again.
    std::optional<DecodedImage> image = render->decodedByLayout(src);
    if (!image) {
        image = render->decodeImageUncached(src);
        if (!image) {
            return std::nullopt;
        }
    }
    if (m_images.size() >= m_sweepAt) {
        // The sweep visits every entry (V5d fix-wave 2 review, I-1).
        std::erase_if(m_images, [](const auto& entry) { return entry.second.image.expired(); });
        m_sweepAt = std::max<size_t>(256, 2 * m_images.size());
    }
    m_images[key] = SharedImage{image->image, image->width, image->height};
    return image;
}

void CanvasState::reportLimit(const char* kind) {
    if (std::find(m_reported.begin(), m_reported.end(), kind) == m_reported.end()) {
        m_reported.emplace_back(kind);
        Runtime::from(m_ctx).host().diagnostic("render-limit", kind);
    }
}

double CanvasState::textWidth(const HostFont& font, std::string_view utf8) {
    RenderHost* render = this->host();
    if (!render || utf8.empty()) {
        return 0;
    }
    // Shaped, not RenderHost::textWidth: the iOS host keeps every text that measure sees in a process-wide cache (V5d
    // final review, C1); shape makes its line and lets it go.
    double width = 0;
    for (float advance : render->shape(font, utf8).advances) {
        width += advance;
    }
    return width;
}

std::optional<DecodedImage> CanvasState::snapshot(uint64_t serial) const {
    auto found = m_contexts->bySerial.find(serial);
    if (found == m_contexts->bySerial.end()) {
        return std::nullopt;
    }
    std::shared_ptr<const HostImage> image = found->second->snapshot();
    if (!image) {
        return std::nullopt;
    }
    const auto [width, height] = found->second->bitmapSize();
    return DecodedImage{std::move(image), double(width), double(height)};
}

void CanvasState::attributeChanged(Element& element, JSAtom localName, Namespace ns) {
    if (ns != Namespace::None || element.ns() != Namespace::HTML) {
        return;
    }
    if (element.localNameAtom() == m_dom.name(Name::img) && localName == m_dom.name(Name::src)) {
        if (auto* image = dynamic_cast<HTMLImageElement*>(&element)) {
            imageSourceChanged(m_ctx, *image);
        }
        return;
    }
    if (element.localNameAtom() != m_dom.name(Name::canvas) ||
        (localName != m_dom.name(Name::width) && localName != m_dom.name(Name::height))) {
        return;
    }
    if (auto* canvas = dynamic_cast<HTMLCanvasElement*>(&element)) {
        canvas->dimensionsChanged(m_ctx);
    }
}

} // namespace wr::canvas
