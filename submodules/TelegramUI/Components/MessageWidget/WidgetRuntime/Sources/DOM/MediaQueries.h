// CSSOM View's media queries (V3b plan, Task 1): MediaQueryList, MediaQueryListEvent, and Window's matchMedia and change
// reporting (MediaQueries.cpp). A list answers through RenderTree::matchesMedia, the media query parser and the media
// features @media uses, so the two always agree.
#pragma once

#include <optional>
#include <string>

#include "Generated/Bindings.h"
#include "Sources/Support/Allocator.h"
#include "Sources/Events/Event.h"
#include "Sources/Events/EventTarget.h"

namespace wr {

class MediaQueryList final : public EventTarget {
public:
    /// `matches` is the answer at creation, as of the render tree's `report`-th media report.
    MediaQueryList(JSContext* ctx, const std::string& media, bool matches, uint64_t report, uint64_t sequence)
        : m_media(media.begin(), media.end(), JSAllocator<char>(JS_GetRuntime(ctx))), m_lastMatches(matches),
          m_lastReport(report), m_sequence(sequence) {}

    // MediaQueryList
    String media(JSContext* ctx);
    /// Evaluated now, against the current media features (CSSOM View).
    bool matches(JSContext* ctx);
    /// The legacy aliases of add/removeEventListener('change', callback).
    void addListener(JSContext* ctx, std::optional<CallbackInterface> callback);
    void removeListener(JSContext* ctx, std::optional<CallbackInterface> callback);

protected:
    /// While the list has a change listener the window holds it, so an event still reaches a list the widget dropped.
    void listenersChanged(JSContext* ctx) override;

private:
    friend class Window;
    /// The query as `media` gives it (at most kMaxMediaQueryBytes), in counted memory.
    std::basic_string<char, std::char_traits<char>, JSAllocator<char>> m_media;
    std::string query() const { return std::string(m_media.data(), m_media.size()); }
    /// The answer at the m_lastReport-th media report (RenderTree::mediaReports), what the next report compares with.
    bool m_lastMatches;
    uint64_t m_lastReport;
    /// Creation order: the report visits the lists oldest first.
    uint64_t m_sequence;
    bool m_held = false;
};

class MediaQueryListEvent final : public Event {
public:
    explicit MediaQueryListEvent(JSContext* ctx) : Event(ctx) {}
    static Ref<MediaQueryListEvent> construct(JSContext* ctx, String type, idl::MediaQueryListEventInit init);
    String media(JSContext* ctx);
    bool matches(JSContext*) { return m_matches; }
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    Held m_media;
    bool m_matches = false;
};

} // namespace wr
