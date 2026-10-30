// HTML's "report an exception" (https://html.spec.whatwg.org/#report-an-exception) and WebIDL's "invoke a callback
// function" with "report".
#pragma once

#include <cstdint>
#include <string>

#include "quickjs.h"
#include "Sources/Support/Values.h"

namespace wr {

/// Reports `exception` (taking the reference) for the window. A fatal exception (a stop, out of memory, any once
/// the runtime has stopped) latches the runtime and throws Aborted instead. Otherwise it fires a cancelable ErrorEvent
/// at the window unless the window is already reporting (HTML's error reporting mode), and when the event was not
/// canceled, posts Host::diagnostic("uncaught-exception", …). The message is "Uncaught " + ToString(exception) and the
/// location the first located frame of its `stack` (Ruling 14): both are read as HTML's "extract error information"
/// may, and one that throws gives a fixed text or no location, its own exception dropped rather than reported in turn
/// (R5). Those reads count as script (Runtime::ConversionScope), so no microtask checkpoint runs inside them; the
/// ErrorEvent's listeners are outermost calls as usual. Throws only Aborted: a native failure on the way (out of memory,
/// the host's diagnostic) latches.
void reportTheException(JSContext* ctx, JSValue exception);
/// Calls `fn` (this `thisArg`) and reports what it throws. Returns its value (undefined after a report). Throws Aborted.
Value invokeWithReport(JSContext* ctx, JSValueConst fn, JSValueConst thisArg, int argc, JSValueConst* argv);
/// `prefix` + ToString(value), the string cut at kMaxDiagnosticBytes, for Host::diagnostic; "exception" in its place
/// when ToString throws. The conversion counts as script (Runtime::ConversionScope). Throws only Aborted.
std::string describeForHost(JSContext* ctx, JSValueConst value, const char* prefix);

struct ErrorLocation {
    /// The empty string when there is no location.
    String filename;
    uint32_t lineno = 0;
    uint32_t colno = 0;
};
/// The first frame of an Error's `stack` that has a location ("    at f (file:12:7)" or, for a syntax error,
/// "    at file:12:7"); empty for anything else, and when reading `stack` throws. The `stack` read counts as script
/// (Runtime::ConversionScope). The stack is read in place. Throws only Aborted.
ErrorLocation errorLocation(JSContext* ctx, JSValueConst exception);

} // namespace wr
