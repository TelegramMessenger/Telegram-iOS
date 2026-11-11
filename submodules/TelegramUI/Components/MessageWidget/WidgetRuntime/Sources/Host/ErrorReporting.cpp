#include "Sources/Host/ErrorReporting.h"

#include <optional>

#include "Generated/Bindings.h"
#include "Sources/Events/Dispatch.h"
#include "Sources/Events/Event.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/HostState.h"
#include "Sources/Host/Window.h"
#include "Sources/Runtime/Host.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Callbacks.h"

namespace wr {

namespace {

/// ToString(value), or nullopt when ToString threw (a Symbol, a throwing toString): that exception is dropped, not
/// reported, so a report cannot recurse through it (R5). The conversion counts as script (Runtime::ConversionScope): no
/// checkpoint runs inside it. A stop (the CPU slice, out of memory) throws Aborted.
std::optional<String> stringOf(JSContext* ctx, JSValueConst value) {
    try {
        Runtime::ConversionScope conversion(Runtime::from(ctx));
        return String::adopt(ctx, checked(ctx, JS_ToString(ctx, value)));
    } catch (const Thrown&) {
        Value failure = Value::adopt(ctx, JS_GetException(ctx));
        throwIfFatal(ctx, failure.get());
        return std::nullopt;
    }
}

/// A flat string's code units, read in place.
struct Units {
    JSStringView view;
    uint32_t operator[](uint32_t i) const { return view.latin1 ? view.latin1[i] : view.utf16[i]; }
};

/// The decimal number in [begin, end): one to nine digits.
bool parseNumber(const Units& s, uint32_t begin, uint32_t end, uint32_t* out) {
    if (begin >= end || end - begin > 9) {
        return false;
    }
    uint32_t n = 0;
    for (uint32_t i = begin; i < end; i++) {
        uint32_t c = s[i];
        if (c < '0' || c > '9') {
            return false;
        }
        n = n * 10 + (c - '0');
    }
    *out = n;
    return true;
}

/// The last `c` in [begin, end), or UINT32_MAX.
uint32_t lastOf(const Units& s, uint32_t begin, uint32_t end, uint32_t c) {
    for (uint32_t i = end; i-- > begin;) {
        if (s[i] == c) {
            return i;
        }
    }
    return UINT32_MAX;
}

/// One line [begin, end) of a QuickJS backtrace: "    at f (file:12:7)", or "    at file:12:7" for a syntax error.
/// The filename's range [*fileBegin, *fileEnd) and the numbers, or false. Each unit is visited a bounded number of
/// times.
bool parseFrame(const Units& s, uint32_t begin, uint32_t end, uint32_t* fileBegin, uint32_t* fileEnd, uint32_t* lineno, uint32_t* colno) {
    static constexpr char kAt[] = "    at ";
    constexpr uint32_t kAtLength = sizeof(kAt) - 1;
    if (end - begin < kAtLength) {
        return false;
    }
    for (uint32_t i = 0; i < kAtLength; i++) {
        if (s[begin + i] != uint32_t(uint8_t(kAt[i]))) {
            return false;
        }
    }
    uint32_t restBegin = begin + kAtLength;
    uint32_t restEnd = end;
    if (restEnd > restBegin && s[restEnd - 1] == ')') {
        // "f (location)": the location follows the last " (".
        uint32_t open = UINT32_MAX;
        for (uint32_t i = restEnd - 1; i > restBegin; i--) {
            if (s[i] == '(' && s[i - 1] == ' ') {
                open = i;
                break;
            }
        }
        if (open == UINT32_MAX) {
            return false;
        }
        restBegin = open + 1;
        restEnd -= 1;
    }
    uint32_t colon2 = lastOf(s, restBegin, restEnd, ':');
    if (colon2 == UINT32_MAX || colon2 == restBegin) {
        return false;
    }
    uint32_t colon1 = lastOf(s, restBegin, colon2, ':');
    if (colon1 == UINT32_MAX) {
        return false;
    }
    if (!parseNumber(s, colon1 + 1, colon2, lineno) || !parseNumber(s, colon2 + 1, restEnd, colno)) {
        return false;
    }
    *fileBegin = restBegin;
    *fileEnd = colon1;
    return true;
}

} // namespace

ErrorLocation errorLocation(JSContext* ctx, JSValueConst exception) {
    ErrorLocation location;
    if (!JS_IsError(exception)) {
        return location;
    }
    try {
        // A JS-visible read (a script can redefine `stack`), counted as script like the conversions; a throwing getter
        // gives no location.
        Value stack;
        {
            Runtime::ConversionScope conversion(Runtime::from(ctx));
            stack = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, exception, "stack")));
        }
        if (!JS_IsString(stack.get())) {
            return location;
        }
        std::optional<String> text = stringOf(ctx, stack.get());
        if (!text) {
            return location;
        }
        Units s{text->view()};
        uint32_t length = s.view.length;
        for (uint32_t start = 0; start < length;) {
            uint32_t end = start;
            while (end < length && s[end] != '\n') {
                end++;
            }
            uint32_t fileBegin = 0, fileEnd = 0, lineno = 0, colno = 0;
            if (parseFrame(s, start, end, &fileBegin, &fileEnd, &lineno, &colno)) {
                location.filename = text->substring(ctx, fileBegin, fileEnd);
                location.lineno = lineno;
                location.colno = colno;
                return location;
            }
            start = end + 1;
        }
        return location;
    } catch (const Thrown&) {
        Value failure = Value::adopt(ctx, JS_GetException(ctx));
        throwIfFatal(ctx, failure.get());
        return ErrorLocation{};
    } catch (...) {
        abortForCaughtException(ctx);
    }
}

std::string describeForHost(JSContext* ctx, JSValueConst value, const char* prefix) {
    try {
        std::optional<String> text = stringOf(ctx, value);
        return prefix + (text ? text->utf8Prefix(kMaxDiagnosticBytes, nullptr) : std::string("exception"));
    } catch (...) {
        abortForCaughtException(ctx);
    }
}

void reportTheException(JSContext* ctx, JSValue owned) {
    Value exception = Value::adopt(ctx, owned);
    try {
        throwIfFatal(ctx, exception.get());
        EventLoop& loop = EventLoop::of(ctx);
        // HTML "extract error information" (Ruling 14).
        std::optional<String> text = stringOf(ctx, exception.get());
        ErrorLocation location = errorLocation(ctx, exception.get());
        bool notHandled = true;
        if (!loop.reportingError()) {
            // HTML's error reporting mode: an exception thrown while the ErrorEvent is dispatched goes to the host only.
            loop.setReportingError(true);
            struct Reset {
                EventLoop& loop;
                ~Reset() { loop.setReportingError(false); }
            } reset{loop};
            idl::ErrorEventInit init;
            init.cancelable = true;
            init.message = String::fromUTF8(ctx, "Uncaught ").concat(ctx, text ? *text : String::fromUTF8(ctx, "exception"));
            init.filename = location.filename;
            init.lineno = location.lineno;
            init.colno = location.colno;
            init.error = Value::dup(ctx, exception.get());
            Ref<ErrorEvent> event = ErrorEvent::construct(ctx, String::fromUTF8(ctx, "error"), std::move(init));
            event->setIsTrusted(true);
            // A listener's exception is reported inside dispatch (here, to the host only); a stop in one throws Aborted,
            // and dispatch's own failure (the memory limit) Thrown or std::bad_alloc (C3): the catch below makes each
            // Aborted.
            notHandled = dispatch(ctx, *event, HostState::of(ctx).window());
        }
        if (notHandled) {
            std::string detail = "Uncaught " + (text ? text->utf8Prefix(kMaxDiagnosticBytes, nullptr) : std::string("exception"));
            if (!location.filename.empty()) {
                detail += " (" + location.filename.utf8Prefix(kMaxDiagnosticBytes, nullptr) + ":" + std::to_string(location.lineno) + ":" +
                          std::to_string(location.colno) + ")";
            }
            Runtime::from(ctx).host().diagnostic("uncaught-exception", detail);
        }
    } catch (...) {
        abortForCaughtException(ctx);
    }
}

Value invokeWithReport(JSContext* ctx, JSValueConst fn, JSValueConst thisArg, int argc, JSValueConst* argv) {
    CallResult result = callFunction(ctx, fn, thisArg, argc, argv);
    if (result.status == CallStatus::Threw) {
        reportTheException(ctx, result.value.release());
        return Value::adopt(ctx, JS_UNDEFINED);
    }
    return std::move(result.value);
}

} // namespace wr
