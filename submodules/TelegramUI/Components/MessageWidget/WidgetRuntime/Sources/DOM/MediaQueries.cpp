#include "Sources/DOM/MediaQueries.h"

#include <algorithm>
#include <vector>

#include "Sources/Events/Dispatch.h"
#include "Sources/Host/HostState.h"
#include "Sources/Host/Window.h"
#include "Sources/Render/RenderTree.h"

namespace wr {

namespace {

/// matchMedia: the longest query parsed (UTF-8 bytes). litehtml's tokenizer allocates outside the memory limit, so a
/// longer query is refused before it is copied: it reads as "not all" (the V3b review's C2; parseSelectors' cap).
constexpr size_t kMaxMediaQueryBytes = 16384;

/// What `media` gives back: the query with its whitespace runs collapsed and its ends trimmed (IDL/README.md: CSSOM
/// View serializes the parsed list instead).
std::string normalizedQuery(const std::string& query) {
    std::string out;
    bool space = false;
    for (char c : query) {
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f') {
            space = !out.empty();
            continue;
        }
        if (space) {
            out += ' ';
            space = false;
        }
        out += c;
    }
    return out;
}

RenderTree* renderOf(JSContext* ctx) {
    HostState* host = HostState::find(ctx);
    return host ? host->render() : nullptr;
}

/// False with no render tree: a document that is not laid out has no media features.
bool evaluate(JSContext* ctx, const std::string& query, bool atLastReport) {
    RenderTree* render = renderOf(ctx);
    return render ? render->matchesMedia(ctx, query, atLastReport) : false;
}

uint64_t reportsOf(JSContext* ctx) {
    RenderTree* render = renderOf(ctx);
    return render ? render->mediaReports() : 0;
}

} // namespace

// MARK: MediaQueryList

String MediaQueryList::media(JSContext* ctx) {
    return String::fromUTF8(ctx, this->query());
}

bool MediaQueryList::matches(JSContext* ctx) {
    return !m_overlong && evaluate(ctx, this->query(), false);
}

void MediaQueryList::addListener(JSContext* ctx, std::optional<CallbackInterface> callback) {
    if (!callback) {
        return;
    }
    Atom type = Atom::fromUTF8(ctx, "change");
    EventTarget::addListener(ctx, type.get(), callback->get(), false, std::nullopt, false);
}

void MediaQueryList::removeListener(JSContext* ctx, std::optional<CallbackInterface> callback) {
    if (!callback) {
        return;
    }
    Atom type = Atom::fromUTF8(ctx, "change");
    EventTarget::removeListener(ctx, type.get(), callback->get(), false);
}

void MediaQueryList::listenersChanged(JSContext* ctx) {
    Atom type = Atom::fromUTF8(ctx, "change");
    const bool wanted = this->hasListenersFor(ctx, type.get());
    if (wanted == m_held) {
        return;
    }
    Window& window = HostState::of(ctx).window();
    if (wanted) {
        // Not held, the list was not evaluated by the reports since: its answer at the last one is what that report
        // would have stored, and the render tree kept the features it saw.
        const uint64_t reports = reportsOf(ctx);
        if (reports != m_lastReport) {
            m_lastMatches = !m_overlong && evaluate(ctx, this->query(), true);
            m_lastReport = reports;
        }
        window.holdMediaQueryList(ctx, *this);
        m_held = true;
        return;
    }
    // The window's hold may be the last reference: nothing touches the list after it goes. (A script caller holds it
    // for the call, as a dispatch holds its target.)
    m_held = false;
    window.releaseMediaQueryList(ctx, *this);
}

// MARK: MediaQueryListEvent

Ref<MediaQueryListEvent> MediaQueryListEvent::construct(JSContext* ctx, String type, idl::MediaQueryListEventInit init) {
    Ref<MediaQueryListEvent> event = create<MediaQueryListEvent>(ctx, idl::kMediaQueryListEvent, ctx);
    event->constructWith(ctx, type, init.bubbles, init.cancelable, init.composed);
    event->m_media.set(JS_GetRuntime(ctx), init.media.toJS(ctx));
    event->m_matches = init.matches;
    return event;
}

String MediaQueryListEvent::media(JSContext* ctx) {
    return m_media.isUndefined() ? String::fromUTF8(ctx, "") : String::adopt(ctx, JS_DupValue(ctx, m_media.value));
}

void MediaQueryListEvent::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_media.mark(rt, mark);
    Event::trace(rt, mark);
}

void MediaQueryListEvent::dispose(JSRuntime* rt) {
    m_media.clear(rt);
    Event::dispose(rt);
}

// MARK: Window

Ref<MediaQueryList> Window::matchMedia(JSContext* ctx, String query) {
    // Only a prefix is converted: a query past the cap is refused before it is copied (it can never match).
    bool cut = false;
    std::string media = query.utf8Prefix(kMaxMediaQueryBytes, &cut);
    media = cut ? std::string("not all") : normalizedQuery(media);
    // Profile 1's host answers a query of at most kMaxMatchMediaUnits UTF-16 units as written (RB §8.3): a longer one is
    // false whatever the features say, though its media reads as any other's (V4 plan, Task 8).
    const bool overlong = query.length() > kMaxMatchMediaUnits;
    const bool matches = !overlong && evaluate(ctx, media, false);
    m_mediaQueryListsMade = true;
    return create<MediaQueryList>(ctx, idl::kMediaQueryList, ctx, media, matches, reportsOf(ctx), m_nextMediaQueryList++,
                                  overlong);
}

void Window::holdMediaQueryList(JSContext* ctx, MediaQueryList& list) {
    if (!m_heldMediaQueryLists) {
        void* memory = js_malloc(ctx, sizeof(Vector<Held>));
        if (!memory) {
            throw Thrown{};
        }
        m_heldMediaQueryLists = new (memory) Vector<Held>(JSAllocator<Held>(JS_GetRuntime(ctx)));
    }
    m_heldMediaQueryLists->push_back(Held{list.newRef(ctx)});
}

void Window::releaseMediaQueryList(JSContext* ctx, MediaQueryList& list) {
    if (!m_heldMediaQueryLists) {
        return;
    }
    for (size_t i = 0; i < m_heldMediaQueryLists->size(); i++) {
        if (payloadOfKnown((*m_heldMediaQueryLists)[i].value) == &list) {
            Held held = (*m_heldMediaQueryLists)[i];
            m_heldMediaQueryLists->erase(m_heldMediaQueryLists->begin() + ptrdiff_t(i));
            held.clear(JS_GetRuntime(ctx));
            return;
        }
    }
}

void Window::reportMediaChanges(JSContext* ctx) {
    RenderTree* render = renderOf(ctx);
    if (!render || !m_mediaQueryListsMade) {
        return;
    }
    // The lists this report visits, oldest first, held for it: a listener may add or remove lists.
    std::vector<Ref<MediaQueryList>> lists;
    if (m_heldMediaQueryLists) {
        for (const Held& held : *m_heldMediaQueryLists) {
            lists.push_back(Ref<MediaQueryList>::retain(ctx, static_cast<MediaQueryList*>(payloadOfKnown(held.value))));
        }
    }
    std::sort(lists.begin(), lists.end(), [](const Ref<MediaQueryList>& a, const Ref<MediaQueryList>& b) {
        return a->m_sequence < b->m_sequence;
    });
    const uint64_t report = render->mediaReports() + 1;
    std::vector<Ref<MediaQueryList>> changed;
    for (Ref<MediaQueryList>& list : lists) {
        const bool now = !list->m_overlong && render->matchesMedia(ctx, list->query(), false);
        if (now != list->m_lastMatches) {
            list->m_lastMatches = now;
            changed.push_back(list);
        }
        list->m_lastReport = report;
    }
    render->noteMediaReported();
    // CSSOM View: fire a change, a MediaQueryListEvent with the list's media and its new answer.
    for (Ref<MediaQueryList>& list : changed) {
        idl::MediaQueryListEventInit init;
        init.media = String::fromUTF8(ctx, list->query());
        init.matches = list->m_lastMatches;
        Ref<MediaQueryListEvent> event = MediaQueryListEvent::construct(ctx, String::fromUTF8(ctx, "change"), init);
        event->setIsTrusted(true);
        dispatch(ctx, *event, *list);
    }
}

} // namespace wr
