// WebIDL callback values: callback functions (Function, EventHandlerNonNull, FrameRequestCallback) and callback
// interfaces (EventListener), as conversions produce them, and HeldCallback, the storage payloads and host state keep
// them in. Calling one is callFunction/callInterface (Task 5).
#pragma once

#include <cassert>
#include <cstdint>
#include <optional>
#include <utility>

#include "quickjs.h"
#include "Sources/Support/Bindings.h"

namespace wr {

/// A callback function value inside a call. The converter requires it to be callable.
class Callback : public Value {
public:
    Callback() = default;
    explicit Callback(Value v) : Value(std::move(v)) {}
};

/// A callback function under [LegacyTreatNonObjectAsNull] (HTML's EventHandlerNonNull): any object, callable or not.
/// It exists only nullable, Converter<std::optional<LegacyCallback>>: a non-object converts to null.
class LegacyCallback : public Callback {
public:
    LegacyCallback() = default;
    explicit LegacyCallback(Value v) : Callback(std::move(v)) {}
};

/// A callback interface value (EventListener): a function, or an object whose operation is read when it is called
/// (WebIDL "call a user object's operation"). The converter requires an object.
class CallbackInterface : public Value {
public:
    CallbackInterface() = default;
    explicit CallbackInterface(Value v) : Value(std::move(v)) {}
    bool isFunction(JSContext* ctx) const { return JS_IsFunction(ctx, this->get()); }
};

/// A callback kept by a payload or by host state: one counted reference. It is released with the runtime (no context
/// needed) and reported in trace(). It is move-only, so a list of them can never release one value twice. Like Held,
/// it has no destructor: its owner clears it in dispose(), or before dropping it. Moving into a non-empty HeldCallback
/// is a programming error (asserted), because it would leak the value it overwrites.
class HeldCallback {
public:
    HeldCallback() = default;
    HeldCallback(HeldCallback&& other) noexcept : m_value(other.m_value) { other.m_value = JS_UNDEFINED; }
    HeldCallback& operator=(HeldCallback&& other) noexcept {
        if (this != &other) {
            assert(JS_IsUndefined(m_value) && "assigning over a held callback leaks it: clear it first");
            m_value = other.m_value;
            other.m_value = JS_UNDEFINED;
        }
        return *this;
    }
    HeldCallback(const HeldCallback&) = delete;
    HeldCallback& operator=(const HeldCallback&) = delete;

    /// Replaces the value, taking over `owned` and releasing the old one.
    void set(JSRuntime* rt, JSValue owned) {
        JSValue old = m_value;
        m_value = owned;
        JS_FreeValueRT(rt, old);
    }
    void clear(JSRuntime* rt) { this->set(rt, JS_UNDEFINED); }
    void mark(JSRuntime* rt, JS_MarkFunc* markFunc) const { JS_MarkValue(rt, m_value, markFunc); }
    /// Borrowed.
    JSValueConst get() const { return m_value; }
    bool empty() const { return JS_IsUndefined(m_value); }

private:
    JSValue m_value = JS_UNDEFINED;
};

template <> Callback Converter<Callback>::from(JSContext*, JSValueConst, const ArgInfo&);
template <> CallbackInterface Converter<CallbackInterface>::from(JSContext*, JSValueConst, const ArgInfo&);

/// [LegacyTreatNonObjectAsNull]: a non-object (undefined, null, a number, a string) converts to null; any object is
/// kept, callable or not.
template <>
struct Converter<std::optional<LegacyCallback>> {
    static std::optional<LegacyCallback> from(JSContext* ctx, JSValueConst v, const ArgInfo& info);
};

enum class CallStatus : uint8_t { Returned, Threw };

/// What a call into JS gave back: its return value, or the (catchable) exception it threw. An uncatchable stop is never
/// a CallResult: the call throws Aborted instead.
struct CallResult {
    CallStatus status;
    Value value;
};

/// Calls `fn` with `thisArg` and the arguments. Counts as a call into JS (Runtime::scriptDepth); when it is the
/// outermost one the host's cleanup hook (the microtask checkpoint) runs before it returns. Throws Aborted when the
/// runtime is stopped or the call stops it.
/// `fn`, `thisArg` and the arguments are borrowed, and QuickJS does not take a reference to them for the call: pass
/// values the caller owns for the whole call. A HeldCallback's get() is not one (script the call runs can clear the
/// callback and free the running function): duplicate it into a Value first.
CallResult callFunction(JSContext* ctx, JSValueConst fn, JSValueConst thisArg, int argc, JSValueConst* argv);

/// WebIDL "call a user object's operation": a callable `object` is called with `thisArg`; otherwise its `name`
/// property is read (a JS-visible Get, the one WebIDL mandates, inside the same call) and called with the object as
/// `this`, a TypeError result when it is not callable. Counted and aborting as callFunction, and borrowing its values
/// as callFunction does: the caller owns `object` for the whole call.
CallResult callInterface(JSContext* ctx, JSValueConst object, const char* name, JSValueConst thisArg, int argc, JSValueConst* argv);

/// For an exception that reached C++ other than through callFunction/callInterface (a job's failure, a failed JS_Eval,
/// JS_ToString or JS_GetProperty): throws Aborted, latching the runtime, when it cannot be caught (the runtime has
/// stopped, QuickJS's out of memory, an uncatchable error); otherwise returns, and the caller reports it. Borrows
/// `exception`. Forwards to Runtime::throwIfFatal.
void throwIfFatal(JSContext* ctx, JSValueConst exception);

/// Inside a catch block, for a native path that may throw only Aborted (the report, the microtask checkpoint): latches
/// what the C++ exception being handled means and throws Aborted. Aborted passes on as it is; Thrown is classified by its
/// pending exception, a catchable one latching Internal; std::bad_alloc latches Memory; anything else Internal. Forwards
/// to Runtime::abortForCaughtException.
[[noreturn]] void abortForCaughtException(JSContext* ctx);

} // namespace wr
