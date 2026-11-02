// C++ exceptions inside the runtime, and `glue`, the one place they become JS exceptions.
#pragma once

#include <exception>
#include <new>
#include <string>

#include "quickjs.h"

namespace wr {

/// A JS exception is already pending in the context.
struct Thrown {};
/// Becomes a DOMException named `name`.
struct DOMError {
    const char* name;
    std::string message;
};
struct TypeError {
    std::string message;
};
struct RangeError {
    std::string message;
};
/// An uncatchable stop: a CPU or layout-query limit, a counted cap, out of memory, or an internal C++ failure latched
/// the runtime (Runtime::stopReason). It unwinds every native frame up to the step boundary. Where it crosses back into
/// a script that called in (a binding), rethrowAsJS turns it into QuickJS's uncatchable "interrupted", and the latch
/// has stopped QuickJS's runtime (quickjs-ng change 10), so no try/catch can swallow it on the way out, even as the
/// bare null QuickJS throws when it cannot build that error.
struct Aborted {};

/// Makes the C++ exception being handled the pending JS exception, and returns JS_EXCEPTION. Call it only inside a
/// catch block. Thrown leaves the exception already pending as it is (it may be the uncatchable interrupt of a stop
/// latched at a poll; on a stopped runtime nothing pending can be caught, quickjs-ng change 10);
/// DOMError becomes a DOMException, TypeError and RangeError their JS errors. Aborted, std::bad_alloc and any other
/// C++ exception stop the runtime for good (Memory for bad_alloc, Internal for the rest) and become an uncatchable
/// error. Every place C++ hands control back to QuickJS maps through this one function.
JSValue rethrowAsJS(JSContext* ctx) noexcept;

/// One native frame (Ruling 6, mutation depth): a binding call (glue) or a MutationScope. Runtime::nativeDepth counts
/// them since the last call into JS. When the outermost one is left normally, the work an extension queued for
/// "native exit" runs: dynamically inserted scripts are prepared there, when no native algorithm is running.
/// Defined in Runtime.cpp.
class NativeFrame {
public:
    explicit NativeFrame(JSContext* ctx);
    /// Leaves on the unwinding path without running anything (an exception is on its way out).
    ~NativeFrame();
    /// Leaves normally. At the outermost frame it runs the queued native-exit work, which can throw (Aborted, Thrown).
    void leave();
    NativeFrame(const NativeFrame&) = delete;
    NativeFrame& operator=(const NativeFrame&) = delete;

private:
    JSContext* m_ctx;
    bool m_left = false;
};

/// Runs a binding's body: counts it as a native frame, and maps every C++ exception to a JS one.
/// Nothing escapes. The native-exit work (scripts the body inserted) runs before the result goes back to JS.
template <class F>
JSValue glue(JSContext* ctx, F&& body) noexcept {
    try {
        NativeFrame frame(ctx);
        JSValue result = body();
        if (JS_IsException(result)) {
            // The body returned with a JS exception pending: leave on the unwinding path (the destructor). Queued
            // native-exit work stays queued for the next outermost frame left normally, or the task's end.
            return result;
        }
        try {
            frame.leave();
        } catch (...) {
            JS_FreeValue(ctx, result);
            throw;
        }
        return result;
    } catch (...) {
        return rethrowAsJS(ctx);
    }
}

/// Returns `v`, or throws Thrown when it is the exception marker.
inline JSValue checked(JSContext* ctx, JSValue v) {
    if (JS_IsException(v)) {
        throw Thrown{};
    }
    return v;
}

/// Throws Thrown for a negative QuickJS status.
inline void check(JSContext* ctx, int status) {
    if (status < 0) {
        throw Thrown{};
    }
}

} // namespace wr
