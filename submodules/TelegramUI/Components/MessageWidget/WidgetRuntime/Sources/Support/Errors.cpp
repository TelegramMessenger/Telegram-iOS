#include "Sources/Support/Errors.h"

#include "Sources/Runtime/Runtime.h"

namespace wr {

namespace {

/// Marks the exception just thrown uncatchable, as quickjs.c's JS_ThrowInterrupted does. Every caller has latched a stop,
/// which already makes whatever is pending uncatchable (quickjs-ng change 10), bare null included when the error could
/// not be built; the mark keeps the value itself uncatchable for a reader that sees only it (JS_IsUncatchableError).
JSValue makePendingUncatchable(JSContext* ctx) {
    JSValue error = JS_GetException(ctx);
    JS_SetUncatchableError(ctx, error);
    return JS_Throw(ctx, error);
}

} // namespace

JSValue rethrowAsJS(JSContext* ctx) noexcept {
    try {
        throw;
    } catch (const Thrown&) {
        return JS_EXCEPTION;
    } catch (const Aborted&) {
        // Already latched where it started: only the way out remains.
        JS_ThrowInternalError(ctx, "interrupted");
        return makePendingUncatchable(ctx);
    } catch (const DOMError& e) {
        return JS_ThrowDOMException(ctx, e.name, "%s", e.message.c_str());
    } catch (const TypeError& e) {
        return JS_ThrowTypeError(ctx, "%s", e.message.c_str());
    } catch (const RangeError& e) {
        return JS_ThrowRangeError(ctx, "%s", e.message.c_str());
    } catch (const std::bad_alloc&) {
        Runtime::from(ctx).stop(StopReason::Memory);
        JS_ThrowOutOfMemory(ctx);
        return makePendingUncatchable(ctx);
    } catch (const std::exception& e) {
        Runtime::from(ctx).stop(StopReason::Internal);
        JS_ThrowInternalError(ctx, "native error: %s", e.what());
        return makePendingUncatchable(ctx);
    } catch (...) {
        Runtime::from(ctx).stop(StopReason::Internal);
        JS_ThrowInternalError(ctx, "native error");
        return makePendingUncatchable(ctx);
    }
}

} // namespace wr
