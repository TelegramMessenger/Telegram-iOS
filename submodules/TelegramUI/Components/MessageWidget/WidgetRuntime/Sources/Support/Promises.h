// A promise a platform object keeps and settles later (V5e plan, Task 3: Animation's ready and finished). Resolving is
// synchronous where the standard's is (it reads the value's `then`, which can run script, so it comes last in an
// algorithm; WPT checks that the read happens inside the call); rejecting with a DOMException is a queued job, since
// making the exception can run the widget's Error.prepareStackTrace. A slot whose settling is queued counts as settled.
#pragma once

#include "quickjs.h"
#include "Sources/Support/Values.h"

namespace wr {

struct PromiseSlot {
    Held promise;
    Held resolve;
    Held reject;
    /// Settled, or its settling is queued.
    bool settled = false;

    void mark(JSRuntime* rt, JS_MarkFunc* markFunc) const {
        promise.mark(rt, markFunc);
        resolve.mark(rt, markFunc);
        reject.mark(rt, markFunc);
    }
    void clear(JSRuntime* rt) {
        promise.clear(rt);
        resolve.clear(rt);
        reject.clear(rt);
    }
};

/// A new pending promise in `slot`, marked handled when `handled` (a rejection is then never reported).
void makePending(JSContext* ctx, PromiseSlot& slot, bool handled);
/// A new promise in `slot`, resolved with `value` now (resolveNow).
void makeResolved(JSContext* ctx, PromiseSlot& slot, JSValueConst value);
/// Resolves the slot with `value` now, where a standard resolves synchronously at the end of an algorithm (Web
/// Animations' finish notification steps): reading `value`'s `then` can run script, so the caller does nothing after
/// it that depends on its own state. The slot is marked settled first; nothing when it already is.
void resolveNow(JSContext* ctx, PromiseSlot& slot, JSValueConst value);
/// Queues the slot's rejection with a new DOMException `name` / `message` (made in the job, where its construction may
/// run the widget's Error.prepareStackTrace); the promise is marked handled now. Nothing when it is already settled.
void queueRejectWithDOMException(JSContext* ctx, PromiseSlot& slot, const char* name, const char* message);

} // namespace wr
