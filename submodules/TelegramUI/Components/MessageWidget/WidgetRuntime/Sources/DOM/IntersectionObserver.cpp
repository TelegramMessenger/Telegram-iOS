#include "Sources/DOM/IntersectionObserver.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <optional>
#include <string>

#include "Sources/DOM/DOM.h"
#include "Sources/Host/ErrorReporting.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/HostState.h"
#include "Sources/Host/Performance.h"
#include "Sources/Host/Task.h"
#include "Sources/Host/Window.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Support/Errors.h"

namespace wr {

namespace {

bool isSpace(char c) {
    return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f';
}

/// One margin token: a number with px or %, or a bare 0.
bool parseMargin(const std::string& token, double& value, bool& percent) {
    size_t unit = token.size();
    percent = false;
    if (token.size() > 1 && token.back() == '%') {
        unit = token.size() - 1;
        percent = true;
    } else if (token.size() > 2 && token.compare(token.size() - 2, 2, "px") == 0) {
        unit = token.size() - 2;
    }
    const std::string number = token.substr(0, unit);
    if (number.empty()) {
        return false;
    }
    char* end = nullptr;
    value = std::strtod(number.c_str(), &end);
    if (end != number.c_str() + number.size() || !std::isfinite(value)) {
        return false;
    }
    // A unitless length is only 0.
    return unit != token.size() || value == 0;
}

std::string formatNumber(double value) {
    if (value == std::floor(value) && std::fabs(value) < 1e15) {
        return std::to_string(static_cast<long long>(value));
    }
    char buffer[32];
    std::snprintf(buffer, sizeof(buffer), "%.17g", value);
    return buffer;
}

RenderBox intersect(const RenderBox& a, const RenderBox& b, bool& adjacent) {
    const double left = std::max(a.x, b.x);
    const double top = std::max(a.y, b.y);
    const double right = std::min(a.x + a.width, b.x + b.width);
    const double bottom = std::min(a.y + a.height, b.y + b.height);
    adjacent = left <= right && top <= bottom;
    return adjacent ? RenderBox{left, top, right - left, bottom - top} : RenderBox{};
}

bool isInclusiveAncestor(const Node* ancestor, const Node* node) {
    for (const Node* n = node; n; n = n->parent()) {
        if (n == ancestor) {
            return true;
        }
    }
    return false;
}

} // namespace

// MARK: IntersectionObserverEntry

DOMRectReadOnly* IntersectionObserverEntry::rootBounds(JSContext*) {
    return m_rootBounds.isUndefined() ? nullptr : static_cast<DOMRectReadOnly*>(payloadOfKnown(m_rootBounds.value));
}

DOMRectReadOnly* IntersectionObserverEntry::boundingClientRect(JSContext*) {
    return static_cast<DOMRectReadOnly*>(payloadOfKnown(m_boundingClientRect.value));
}

DOMRectReadOnly* IntersectionObserverEntry::intersectionRect(JSContext*) {
    return static_cast<DOMRectReadOnly*>(payloadOfKnown(m_intersectionRect.value));
}

Element* IntersectionObserverEntry::target(JSContext*) {
    return static_cast<Element*>(payloadOfKnown(m_target.value));
}

void IntersectionObserverEntry::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_rootBounds.mark(rt, mark);
    m_boundingClientRect.mark(rt, mark);
    m_intersectionRect.mark(rt, mark);
    m_target.mark(rt, mark);
}

void IntersectionObserverEntry::dispose(JSRuntime* rt) {
    m_rootBounds.clear(rt);
    m_boundingClientRect.clear(rt);
    m_intersectionRect.clear(rt);
    m_target.clear(rt);
}

// MARK: IntersectionObserver

IntersectionObserver::IntersectionObserver(JSContext* ctx)
    : m_thresholds(JSAllocator<double>(JS_GetRuntime(ctx))), m_observations(JSAllocator<Observation>(JS_GetRuntime(ctx))),
      m_queue(JSAllocator<Held>(JS_GetRuntime(ctx))) {}

Ref<IntersectionObserver> IntersectionObserver::construct(JSContext* ctx, Callback callback, idl::IntersectionObserverInit options) {
    // rootMargin: one to four tokens, CSS margin order. Nothing longer than kMaxRootMarginBytes is one (the V3b
    // review's I1: refused before it is copied), and the fifth token ends the scan.
    constexpr size_t kMaxRootMarginBytes = 1024;
    bool cut = false;
    const std::string margin = options.rootMargin.utf8Prefix(kMaxRootMarginBytes, &cut);
    if (cut) {
        throw DOMError{"SyntaxError", "rootMargin must be one to four lengths in px or %."};
    }
    std::vector<std::string> tokens;
    for (size_t i = 0; i < margin.size() && tokens.size() <= 4;) {
        while (i < margin.size() && isSpace(margin[i])) {
            i++;
        }
        size_t start = i;
        while (i < margin.size() && !isSpace(margin[i])) {
            i++;
        }
        if (i > start) {
            tokens.push_back(margin.substr(start, i - start));
        }
    }
    if (tokens.empty() || tokens.size() > 4) {
        throw DOMError{"SyntaxError", "rootMargin must be one to four lengths in px or %."};
    }
    std::array<Margin, 4> parsed;
    std::vector<Margin> given;
    for (const std::string& token : tokens) {
        Margin m;
        if (!parseMargin(token, m.value, m.percent)) {
            throw DOMError{"SyntaxError", "rootMargin must be one to four lengths in px or %."};
        }
        given.push_back(m);
    }
    // Top, right, bottom, left, as the margin shorthand fills them.
    parsed[0] = given[0];
    parsed[1] = given.size() > 1 ? given[1] : given[0];
    parsed[2] = given.size() > 2 ? given[2] : given[0];
    parsed[3] = given.size() > 3 ? given[3] : parsed[1];

    // threshold: a number or an array of numbers (WebIDL's (double or sequence<double>), converted here), each checked
    // as it is converted: not a finite number is a TypeError (a restricted double), outside [0, 1] a RangeError.
    Vector<double> thresholds{JSAllocator<double>(JS_GetRuntime(ctx))};
    JSValueConst thresholdValue = options.threshold ? options.threshold->get() : JS_UNDEFINED;
    auto toNumber = [&](JSValueConst v) {
        double d = 0;
        if (JS_ToFloat64(ctx, &d, v) < 0) {
            throw Thrown{};
        }
        if (!std::isfinite(d)) {
            throw TypeError{"Threshold values must be finite numbers."};
        }
        if (d < 0 || d > 1) {
            throw RangeError{"Threshold values must be numbers between 0 and 1."};
        }
        return d;
    };
    if (JS_IsUndefined(thresholdValue)) {
        thresholds.push_back(0);
    } else if (JS_IsArray(thresholdValue)) {
        Value lengthValue = Value::adopt(ctx, JS_GetPropertyStr(ctx, thresholdValue, "length"));
        if (JS_IsException(lengthValue.get())) {
            throw Thrown{};
        }
        double length = 0;
        if (JS_ToFloat64(ctx, &length, lengthValue.get()) < 0) {
            throw Thrown{};
        }
        for (uint32_t i = 0; double(i) < length; i++) {
            Value item = Value::adopt(ctx, JS_GetPropertyUint32(ctx, thresholdValue, i));
            if (JS_IsException(item.get())) {
                throw Thrown{};
            }
            thresholds.push_back(toNumber(item.get()));
        }
    } else {
        thresholds.push_back(toNumber(thresholdValue));
    }
    if (thresholds.empty()) {
        thresholds.push_back(0);
    }
    std::sort(thresholds.begin(), thresholds.end());

    Ref<IntersectionObserver> observer = create<IntersectionObserver>(ctx, idl::kIntersectionObserver, ctx);
    JSRuntime* rt = JS_GetRuntime(ctx);
    observer->m_callback.set(rt, JS_DupValue(ctx, callback.get()));
    if (Element* root = options.root) {
        observer->m_root.set(rt, root->newRef(ctx));
    }
    observer->m_margin = parsed;
    observer->m_thresholds.assign(thresholds.begin(), thresholds.end());
    return observer;
}

Element* IntersectionObserver::root(JSContext*) {
    return m_root.isUndefined() ? nullptr : static_cast<Element*>(payloadOfKnown(m_root.value));
}

String IntersectionObserver::rootMargin(JSContext* ctx) {
    std::string out;
    for (const Margin& m : m_margin) {
        if (!out.empty()) {
            out += ' ';
        }
        out += formatNumber(m.value) + (m.percent ? "%" : "px");
    }
    return String::fromUTF8(ctx, out);
}

Value IntersectionObserver::thresholds(JSContext* ctx) {
    if (m_thresholdsArray.isUndefined()) {
        JSValue array = JS_NewArray(ctx);
        if (JS_IsException(array)) {
            throw Thrown{};
        }
        for (size_t i = 0; i < m_thresholds.size(); i++) {
            if (JS_SetPropertyUint32(ctx, array, uint32_t(i), JS_NewFloat64(ctx, m_thresholds[i])) < 0) {
                JS_FreeValue(ctx, array);
                throw Thrown{};
            }
        }
        if (JS_FreezeObject(ctx, array) < 0) {
            JS_FreeValue(ctx, array);
            throw Thrown{};
        }
        m_thresholdsArray.set(JS_GetRuntime(ctx), array);
    }
    return Value::dup(ctx, m_thresholdsArray.value);
}

void IntersectionObserver::observe(JSContext* ctx, Element* target) {
    for (const Observation& observation : m_observations) {
        if (payloadOfKnown(observation.target.value) == target) {
            return;
        }
    }
    const bool wasEmpty = m_observations.empty();
    Observation observation;
    observation.target.value = target->newRef(ctx);
    m_observations.push_back(observation);
    if (wasEmpty) {
        HostState::of(ctx).window().holdObserver(ctx, *this);
    }
}

void IntersectionObserver::unobserve(JSContext* ctx, Element* target) {
    for (size_t i = 0; i < m_observations.size(); i++) {
        if (payloadOfKnown(m_observations[i].target.value) == target) {
            m_observations[i].target.clear(JS_GetRuntime(ctx));
            m_observations.erase(m_observations.begin() + ptrdiff_t(i));
            if (m_observations.empty()) {
                HostState::of(ctx).window().releaseObserver(ctx, *this);
            }
            return;
        }
    }
}

void IntersectionObserver::disconnect(JSContext* ctx) {
    if (m_observations.empty()) {
        return;
    }
    for (Observation& observation : m_observations) {
        observation.target.clear(JS_GetRuntime(ctx));
    }
    m_observations.clear();
    HostState::of(ctx).window().releaseObserver(ctx, *this);
}

Value IntersectionObserver::queuedArray(JSContext* ctx) {
    JSValue array = JS_NewArray(ctx);
    if (JS_IsException(array)) {
        throw Thrown{};
    }
    Value held = Value::adopt(ctx, array);
    JSRuntime* rt = JS_GetRuntime(ctx);
    uint32_t index = 0;
    for (Held& entry : m_queue) {
        // The array takes the queue's reference.
        JSValue value = entry.value;
        entry.value = JS_UNDEFINED;
        if (JS_SetPropertyUint32(ctx, held.get(), index++, value) < 0) {
            for (Held& rest : m_queue) {
                rest.clear(rt);
            }
            m_queue.clear();
            throw Thrown{};
        }
    }
    m_queue.clear();
    return held;
}

Value IntersectionObserver::takeRecords(JSContext* ctx) {
    return this->queuedArray(ctx);
}

bool IntersectionObserver::update(JSContext* ctx, const RenderTree& render, double time) {
    Element* explicitRoot = this->root(ctx);
    // The root rectangle: the widget's whole area, or the root's padding box when it clips, else its border box.
    std::optional<RenderBox> rootRect;
    if (!explicitRoot) {
        rootRect = RenderBox{0, 0, render.layoutWidth(), render.documentHeight()};
    } else if (std::optional<RenderBox> clip = render.overflowClip(*explicitRoot)) {
        rootRect = render.visualBox(*explicitRoot, clip);
    } else {
        rootRect = render.visualBorderBox(*explicitRoot);
    }
    RenderBox rootBounds;
    if (rootRect) {
        const double w = rootRect->width;
        const double h = rootRect->height;
        auto px = [](const Margin& m, double basis) { return m.percent ? m.value * basis / 100.0 : m.value; };
        const double top = px(m_margin[0], h), right = px(m_margin[1], w), bottom = px(m_margin[2], h), left = px(m_margin[3], w);
        rootBounds = RenderBox{rootRect->x - left, rootRect->y - top, w + left + right, h + top + bottom};
    }
    bool queued = false;
    for (Observation& observation : m_observations) {
        Element& target = *static_cast<Element*>(payloadOfKnown(observation.target.value));
        std::optional<RenderBox> targetRect = render.visualBorderBox(target);
        bool isIntersecting = false;
        RenderBox intersection;
        if (targetRect && rootRect && (!explicitRoot || (explicitRoot != &target && isInclusiveAncestor(explicitRoot, &target)))) {
            RenderBox rect = *targetRect;
            bool adjacent = true;
            for (Element* ancestor = target.parentElementNode(); ancestor && ancestor != explicitRoot && adjacent;
                 ancestor = ancestor->parentElementNode()) {
                if (std::optional<RenderBox> clip = render.visualBox(*ancestor, render.overflowClip(*ancestor))) {
                    rect = intersect(rect, *clip, adjacent);
                }
            }
            if (adjacent) {
                rect = intersect(rect, rootBounds, adjacent);
            }
            isIntersecting = adjacent;
            if (isIntersecting) {
                intersection = rect;
            }
        }
        const double targetArea = targetRect ? targetRect->width * targetRect->height : 0;
        const double ratio = targetArea > 0 ? std::min(1.0, intersection.width * intersection.height / targetArea) : (isIntersecting ? 1.0 : 0.0);
        int thresholdIndex = int(m_thresholds.size());
        for (size_t i = 0; i < m_thresholds.size(); i++) {
            if (m_thresholds[i] > ratio) {
                thresholdIndex = int(i);
                break;
            }
        }
        if (thresholdIndex == observation.previousThresholdIndex && isIntersecting == observation.previousIsIntersecting) {
            continue;
        }
        observation.previousThresholdIndex = thresholdIndex;
        observation.previousIsIntersecting = isIntersecting;
        Ref<IntersectionObserverEntry> entry = create<IntersectionObserverEntry>(ctx, idl::kIntersectionObserverEntry);
        JSRuntime* rt = JS_GetRuntime(ctx);
        entry->m_time = time;
        if (rootRect) {
            entry->m_rootBounds.set(rt, DOMRectReadOnly::make(ctx, rootBounds).release());
        }
        entry->m_boundingClientRect.set(rt, DOMRectReadOnly::make(ctx, targetRect.value_or(RenderBox{})).release());
        entry->m_intersectionRect.set(rt, DOMRectReadOnly::make(ctx, intersection).release());
        entry->m_target.set(rt, target.newRef(ctx));
        entry->m_isIntersecting = isIntersecting;
        entry->m_ratio = ratio;
        m_queue.push_back(Held{entry.release()});
        queued = true;
    }
    return queued;
}

void IntersectionObserver::notify(JSContext* ctx) {
    if (m_queue.empty()) {
        return;
    }
    Value entries = this->queuedArray(ctx);
    Value callback = Value::dup(ctx, m_callback.value);
    Value self = Value::adopt(ctx, this->newRef(ctx));
    JSValueConst argv[2] = {entries.get(), self.get()};
    invokeWithReport(ctx, callback.get(), self.get(), 2, argv);
}

void IntersectionObserver::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_callback.mark(rt, mark);
    m_root.mark(rt, mark);
    m_thresholdsArray.mark(rt, mark);
    for (const Observation& observation : m_observations) {
        observation.target.mark(rt, mark);
    }
    for (const Held& entry : m_queue) {
        entry.mark(rt, mark);
    }
}

void IntersectionObserver::dispose(JSRuntime* rt) {
    m_callback.clear(rt);
    m_root.clear(rt);
    m_thresholdsArray.clear(rt);
    for (Observation& observation : m_observations) {
        observation.target.clear(rt);
    }
    m_observations.clear();
    for (Held& entry : m_queue) {
        entry.clear(rt);
    }
    m_queue.clear();
}

// MARK: Window

void Window::updateIntersectionObservations(JSContext* ctx) {
    RenderTree* render = HostState::of(ctx).render();
    if (!render || !m_observers) {
        return;
    }
    const double time = this->performance(ctx)->now(ctx);
    bool queued = false;
    for (const Ref<IntersectionObserver>& observer : this->heldObservers<IntersectionObserver>(ctx)) {
        queued = observer->update(ctx, *render, time) || queued;
    }
    if (queued && !m_intersectionTaskQueued) {
        m_intersectionTaskQueued = true;
        HostState::of(ctx).loop().queueTask(TaskSource::DOMManipulation, makeTask(ctx, [](JSContext* ctx) {
            HostState::of(ctx).window().notifyIntersectionObservers(ctx);
        }));
    }
}

void Window::notifyIntersectionObservers(JSContext* ctx) {
    m_intersectionTaskQueued = false;
    for (const Ref<IntersectionObserver>& observer : this->heldObservers<IntersectionObserver>(ctx)) {
        observer->notify(ctx);
    }
}

} // namespace wr
