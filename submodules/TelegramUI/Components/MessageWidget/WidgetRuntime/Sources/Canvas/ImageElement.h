// HTMLImageElement (V5d plan, Task 5; HTML "The img element"): what a canvas needs of an image, a source to draw.
// The image's data is the render tree's decision for its src (a data: image the container decoded, the layout's own),
// made at once, so `complete` and the natural size are known synchronously; load and error fire from a task when the
// src changes, and for the parsed images before the window's load.
#pragma once

#include <optional>
#include <string>

#include "Sources/DOM/DOM.h"
#include "Sources/Render/RenderHost.h"

namespace wr {

class HTMLImageElement : public HTMLElement {
public:
    using HTMLElement::HTMLElement;

    /// The rendered size is not known without layout: the attribute when it parses, else the natural size (0 when
    /// there is none). Setting one sets the attribute.
    uint32_t width(JSContext* ctx) const;
    uint32_t height(JSContext* ctx) const;
    void setWidth(JSContext* ctx, uint32_t value);
    void setHeight(JSContext* ctx, uint32_t value);
    uint32_t naturalWidth(JSContext* ctx) const;
    uint32_t naturalHeight(JSContext* ctx) const;
    /// No src (or an empty one), or its decision is made: always true here, since data: images decode at once.
    bool complete(JSContext* ctx) const;
    /// The src when it decoded, else "".
    String currentSrc(JSContext* ctx) const;

    /// HTML's image states: no src (unavailable), decoded (available) or anything else (broken).
    enum class State : uint8_t { Unavailable, Available, Broken };
    /// The state and, when available, the decoded image.
    State state(JSContext* ctx, std::optional<DecodedImage>* decoded = nullptr) const;

    /// Whether a load or error event was queued or fired for this element: the parsed images get theirs before the
    /// window's load (fireParsedImageEvents), once.
    bool eventQueued() const { return m_eventQueued; }
    void setEventQueued() { m_eventQueued = true; }
    /// The src changed: the next question decides again.
    void forgetDecision() {
        m_decided = false;
        m_decoded.reset();
    }

private:
    bool m_eventQueued = false;
    /// The decision for the current src, kept until the src changes (V5d final review, I3: a build drops the decisions
    /// it did not use, and a detached sprite is never used by one); no copy of the src is kept (fix-wave review, C-A).
    mutable bool m_decided = false;
    mutable std::optional<DecodedImage> m_decoded;
};

/// An img was made: its src's change steps (CanvasState) watch from now on. Nothing in a runtime without a host.
void imageCreated(JSContext* ctx);
/// The src of the HTML img `element` changed (CanvasState's attribute change steps): a task fires load or error at it,
/// per its state when the task runs; a removed or empty src fires nothing.
void imageSourceChanged(JSContext* ctx, HTMLImageElement& element);
/// HTML's legacy factory function `Image(width, height)` (V5d final review, I4), a lazy global: `new Image()` makes an
/// img in the main document, with its width and height attributes when given; its `prototype` is HTMLImageElement's.
void installImageConstructor(JSContext* ctx);
/// The parsed images that have a src and no event yet get load or error now, in tree order (boot's Load phase, before
/// the window's load).
void fireParsedImageEvents(JSContext* ctx);

} // namespace wr
