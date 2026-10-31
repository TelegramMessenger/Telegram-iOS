// The canvases' per-runtime state (V5d plan, Task 3): the bitmap allowance, the fonts canvas text measures and draws
// with, the change steps of a canvas's width and height attributes, and (Task 5) of an img's src. Made by the first
// getContext('2d') or <img>, and owned by the HostState.
#pragma once

#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <utility>
#include <vector>

#include "Sources/Canvas/CanvasInterpreter.h"
#include "Sources/Canvas/CanvasStyle.h"
#include "Sources/Canvas/ImageElement.h"
#include "Sources/DOM/Document.h"
#include "Sources/Render/RenderHost.h"
#include "Sources/Support/Allocator.h"

namespace wr {

class CanvasRenderingContext2D;
class DOMState;

namespace canvas {

/// A canvas's bitmap and the pixels it holds of the widget's allowance, returned when it goes. Self-contained: it may
/// outlive the CanvasState (a canvas element collected after the host state is gone).
class Bitmap {
public:
    Bitmap(std::unique_ptr<HostCanvas> canvas, uint64_t pixels, std::shared_ptr<uint64_t> used)
        : canvas(std::move(canvas)), m_pixels(pixels), m_used(std::move(used)) {}
    ~Bitmap() { *m_used -= m_pixels; }
    Bitmap(const Bitmap&) = delete;
    Bitmap& operator=(const Bitmap&) = delete;

    const std::unique_ptr<HostCanvas> canvas;

private:
    uint64_t m_pixels;
    std::shared_ptr<uint64_t> m_used;
};

class CanvasState final : public MutationListener {
public:
    /// The validator's side limit (widget-sandbox v0.1.0 `canvasCmd`, `r`).
    static constexpr int kMaxSide = 16384;
    /// A widget's canvases hold at most this many pixels together: 16 MB of bitmap.
    static constexpr uint64_t kMaxPixels = 4'194'304;
    static constexpr size_t kMaxFonts = 64;

    explicit CanvasState(JSContext* ctx);
    ~CanvasState() override;
    CanvasState(const CanvasState&) = delete;
    CanvasState& operator=(const CanvasState&) = delete;
    /// The runtime's, made on first use.
    static CanvasState& of(JSContext* ctx);

    /// A transparent `width` × `height` bitmap from the render tree's host; nullptr for a side past kMaxSide or 0, past
    /// what is left of kMaxPixels, without a render tree, or when the host makes none. The first refusal on the
    /// allowance posts a `render-limit` diagnostic, `canvas-pixels`.
    std::unique_ptr<Bitmap> allocate(int width, int height);
    /// The font a canvas `font` value stands for (cached by its serialization, at most kMaxFonts), with its metrics;
    /// nullopt without a render tree.
    std::optional<CanvasHost::Font> font(const FontValue& value);
    /// Posts a `render-limit` diagnostic of `kind`, once per kind.
    void reportLimit(const char* kind);
    /// The advance of `utf8` in `font`: the sum of the render tree's host's shaped advances, which keeps nothing (its
    /// textWidth caches every text in a process-wide cache on iOS); 0 without a host.
    double textWidth(const HostFont& font, std::string_view utf8);

    void attributeChanged(Element& element, JSAtom localName, Namespace ns) override;

    /// The canvases with a context, by HTMLCanvasElement::serial: what a twcanvas: source draws (V5d plan, Task 4).
    /// Shared with the contexts, each of which takes itself out when it goes (possibly after this state).
    struct Contexts {
        std::unordered_map<uint64_t, CanvasRenderingContext2D*> bySerial;
    };
    const std::shared_ptr<Contexts>& contexts() const { return m_contexts; }
    /// The pixels of the canvas `serial` names and its bitmap's size; nullopt when it has no context or no bitmap.
    std::optional<DecodedImage> snapshot(uint64_t serial) const;

    /// An <img> source's decoded image, shared by every image with the same src while any of them holds it (V5d
    /// fix-wave review, I-A). Keyed by the src's hash and length, so no copy of the src is kept (C-A). nullopt when
    /// refused, undecodable, or without a render tree.
    std::optional<DecodedImage> sharedImage(std::string_view src);

    /// The images the document's parse left pending (imageSourceChanged): fireParsedImageEvents fires the ones still
    /// waiting at the window's load that belong to the main document, in its tree or taken out of it (v0.2.3 review,
    /// I1). Held until then.
    void addParsedImage(Ref<HTMLImageElement> image) { m_parsedImages.push_back(std::move(image)); }
    Vector<Ref<HTMLImageElement>> takeParsedImages() {
        return std::exchange(m_parsedImages, Vector<Ref<HTMLImageElement>>{m_parsedImages.get_allocator()});
    }

private:
    RenderHost* host() const;

    JSContext* m_ctx;
    DOMState& m_dom;
    std::shared_ptr<uint64_t> m_used = std::make_shared<uint64_t>(0);
    std::vector<std::string> m_reported;
    /// The host the cached fonts came from: a new render tree's host starts the cache again.
    const RenderHost* m_fontHost = nullptr;
    std::unordered_map<std::string, CanvasHost::Font> m_fonts;
    std::shared_ptr<Contexts> m_contexts = std::make_shared<Contexts>();
    struct SharedImage {
        std::weak_ptr<const HostImage> image;
        double width = 0, height = 0;
    };
    struct SharedKeyHash {
        size_t operator()(const std::pair<size_t, size_t>& key) const { return key.first ^ (key.second * 0x9E3779B97F4A7C15ull); }
    };
    std::unordered_map<std::pair<size_t, size_t>, SharedImage, SharedKeyHash> m_images;
    /// The size at which the next sweep of expired entries runs: twice what the last one left, so sweeps cost O(1) per
    /// entry however many images stay alive (V5d fix-wave 2 review, I-1).
    size_t m_sweepAt = 256;
    /// In the JS heap, so the widget's memory limit counts it.
    Vector<Ref<HTMLImageElement>> m_parsedImages{JSAllocator<Ref<HTMLImageElement>>(JS_GetRuntime(m_ctx))};
};

} // namespace canvas
} // namespace wr
