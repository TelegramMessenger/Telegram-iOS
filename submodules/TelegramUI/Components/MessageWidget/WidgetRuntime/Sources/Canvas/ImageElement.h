// HTMLImageElement (V5d plan, Task 5; HTML "The img element"): what a canvas needs of an image, a source to draw.
// The image's data is the render tree's decision for its src (a data: image the container decoded, the layout's own).
// Since widget-sandbox v0.2.3 its state is a browser's: pending from a src change until its load or error fires from a
// task; the parsed images' fire at the window's load, those a script took out of the document included.
#pragma once

#include <optional>
#include <string>

#include "Sources/DOM/DOM.h"
#include "Sources/Render/RenderHost.h"

namespace wr {

class HTMLImageElement : public HTMLElement {
public:
    using HTMLElement::HTMLElement;

    /// The rendered content size while the image is being rendered (a layout query, widget-sandbox v0.2.3), where a
    /// dimension the CSS leaves auto reads 0 while the image is pending (a browser lays it out before it decodes;
    /// `RenderTree::BoxMetrics::autoWidth` / `autoHeight`), else the attribute when it parses, else the natural size (0
    /// when there is none or while pending). Setting one sets the attribute.
    uint32_t width(JSContext* ctx) const;
    uint32_t height(JSContext* ctx) const;
    void setWidth(JSContext* ctx, uint32_t value);
    void setHeight(JSContext* ctx, uint32_t value);
    uint32_t naturalWidth(JSContext* ctx) const;
    uint32_t naturalHeight(JSContext* ctx) const;
    /// Not pending: no src, or its load or error has fired.
    bool complete(JSContext* ctx) const;
    /// The src once it loaded, else "".
    String currentSrc(JSContext* ctx) const;

    /// HTML's image states: no src (unavailable), decoded (available) or anything else (broken).
    enum class State : uint8_t { Unavailable, Available, Broken };
    /// The state and, when available, the decoded image.
    State state(JSContext* ctx, std::optional<DecodedImage>* decoded = nullptr) const;

    /// Whether a load or error event was queued or fired for this element: the parsed images get theirs at the
    /// window's load (fireParsedImageEvents), once.
    bool eventQueued() const { return m_eventQueued; }
    void setEventQueued() { m_eventQueued = true; }
    /// The src changed: the next question decides again.
    void forgetDecision() {
        m_decided = false;
        m_decoded.reset();
    }
    
    /// widget-sandbox v0.2.3 (a browser's image state): from a src change until its load or error fires the image is
    /// pending: not complete, no natural size, not usable on a canvas. A newer change replaces the pending event
    /// (`sourceGeneration`).
    bool pending() const { return m_pending; }
    uint32_t sourceGeneration() const { return m_sourceGeneration; }
    void sourceChanged(bool pending) {
        m_sourceGeneration++;
        m_pending = pending;
    }
    /// Its load or error fires now.
    void settled() { m_pending = false; }

    /// HTML: its adopting steps are a relevant mutation. Adopted into the document, it loads again: an image of a
    /// template's contents, which the parse left pending, loads once a script moves it in (v0.2.3 review, I1).
    void adoptedInto(JSContext* ctx, Document& document) override;

private:
    bool m_eventQueued = false;
    bool m_pending = false;
    uint32_t m_sourceGeneration = 0;
    /// The decision for the current src, kept until the src changes (V5d final review, I3: a build drops the decisions
    /// it did not use, and a detached sprite is never used by one); no copy of the src is kept (fix-wave review, C-A).
    mutable bool m_decided = false;
    mutable std::optional<DecodedImage> m_decoded;
};

/// An img was made: its src's change steps (CanvasState) watch from now on. Nothing in a runtime without a host.
void imageCreated(JSContext* ctx);
/// The src of the HTML img `element` changed (CanvasState's attribute change steps), or it was adopted into the
/// document: it is pending, and a task fires load or error at it per its state when the task runs; a removed src fires
/// nothing. During the document's parse no task is queued: the image waits for fireParsedImageEvents.
void imageSourceChanged(JSContext* ctx, HTMLImageElement& element);
/// HTML's legacy factory function `Image(width, height)` (V5d final review, I4), a lazy global: `new Image()` makes an
/// img in the main document, with its width and height attributes when given; its `prototype` is HTMLImageElement's.
void installImageConstructor(JSContext* ctx);
/// The parsed images that have a src and no event yet get load or error now (boot's Load phase, before the window's
/// load): the document's in tree order, then those a script took out of it. One in a template's contents waits for its
/// adoption into the document.
void fireParsedImageEvents(JSContext* ctx);

} // namespace wr
