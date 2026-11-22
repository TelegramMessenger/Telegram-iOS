#include "Sources/Events/ListenedTypes.h"

#include <new>

#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Callbacks.h"
#include "Sources/Support/Errors.h"
#include "Sources/Support/Values.h"

namespace wr {

namespace {

/// The UTF-8 text of `type`. An atom's string is made without running script, so a failure can only be a stop (out of
/// memory, QuickJS's or the C++ string's): Aborted, after the runtime latched it.
std::string textOf(JSContext* ctx, JSAtom type) {
    try {
        return String::fromAtom(ctx, type).utf8();
    } catch (const Thrown&) {
        Value failure = Value::adopt(ctx, JS_GetException(ctx));
        throwIfFatal(ctx, failure.get());
        Runtime::from(ctx).stop(StopReason::Internal);
        throw Aborted{};
    } catch (const std::bad_alloc&) {
        Runtime::from(ctx).stop(StopReason::Memory);
        throw Aborted{};
    }
}

} // namespace

ListenedTypes::ListenedTypes(JSRuntime* rt)
    : m_rt(rt), m_order(JSAllocator<JSAtom>(rt)), m_set(0, std::hash<JSAtom>(), std::equal_to<JSAtom>(), JSAllocator<JSAtom>(rt)) {}

ListenedTypes::~ListenedTypes() {
    for (JSAtom a : m_order) {
        JS_FreeAtomRT(m_rt, a);
    }
}

void ListenedTypes::note(JSContext* ctx, JSAtom type) {
    if (m_set.count(type)) {
        return;
    }
    JSAtom held = JS_DupAtom(ctx, type);
    try {
        m_order.push_back(held);
    } catch (...) {
        JS_FreeAtom(ctx, held);
        throw;
    }
    try {
        m_set.insert(type);
    } catch (...) {
        m_order.pop_back();
        JS_FreeAtom(ctx, held);
        throw;
    }
}

std::vector<std::string> ListenedTypes::takeIfChanged(JSContext* ctx) {
    std::vector<std::string> out;
    if (!this->changed()) {
        return out;
    }
    try {
        out.reserve(m_order.size() - m_taken);
        for (size_t i = m_taken; i < m_order.size(); i++) {
            out.push_back(textOf(ctx, m_order[i]));
        }
    } catch (const std::bad_alloc&) {
        // The list's own allocation: the stop the header promises, latched first.
        Runtime::from(ctx).stop(StopReason::Memory);
        throw Aborted{};
    }
    // Only once every text was made: a failure takes nothing.
    m_taken = m_order.size();
    return out;
}

} // namespace wr
