#include "Sources/Host/Console.h"

#include <algorithm>
#include <string>
#include <string_view>

#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"
#include "Sources/Support/Values.h"

namespace wr {

namespace {

/// Each helper below appends to a line that holds at most kMaxDiagnosticBytes (Ruling 14's cut: the line is that much
/// of the whole line, at a character boundary), and answers whether the line has room left.

bool appendASCII(std::string& out, std::string_view ascii) {
    size_t room = kMaxDiagnosticBytes - out.size();
    out.append(ascii.substr(0, room));
    return ascii.size() < room;
}

/// The text of a value that is not a symbol: ToString(v), QuickJS's own conversion (it can run the value's toString,
/// as a script's String(v) does), then as much of its UTF-8 as fits (utf8Prefix stops at the first character that does
/// not fit, so it visits at most `room` + 1 units).
bool appendText(JSContext* ctx, std::string& out, JSValueConst v) {
    String text = String::adopt(ctx, checked(ctx, JS_ToString(ctx, v)));
    size_t room = kMaxDiagnosticBytes - out.size();
    bool cut = false;
    out += text.utf8Prefix(room, &cut);
    return !cut && out.size() < kMaxDiagnosticBytes;
}

/// One argument's text: String(v), with a symbol written Symbol(description). It runs as part of the script's own call.
bool appendArgument(JSContext* ctx, std::string& out, JSValueConst v) {
    if (JS_IsSymbol(v)) {
        Value description = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, v, "description")));
        if (!appendASCII(out, "Symbol(")) {
            return false;
        }
        // As text, never as another argument: a script can make every symbol's description a symbol (a data
        // property on Symbol.prototype), and that recursion would have no bound. ToString refuses a symbol.
        if (!JS_IsUndefined(description.get()) && !appendText(ctx, out, description.get())) {
            return false;
        }
        return appendASCII(out, ")");
    }
    return appendText(ctx, out, v);
}

JSValue consoleMethod(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv, int level) {
    return glue(ctx, [&]() -> JSValue {
        std::string line;
        // Once the line is full, the remaining arguments are not converted.
        for (int i = 0; i < argc; i++) {
            if (i > 0 && !appendASCII(line, " ")) {
                break;
            }
            if (!appendArgument(ctx, line, argv[i])) {
                break;
            }
        }
        Runtime::from(ctx).host().log(LogLevel(level), line);
        return JS_UNDEFINED;
    });
}

} // namespace

void installConsole(JSContext* ctx) {
    Value console = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
    static const struct {
        const char* name;
        LogLevel level;
    } kMethods[] = {
        {"log", LogLevel::Log}, {"info", LogLevel::Info}, {"warn", LogLevel::Warn}, {"error", LogLevel::Error}, {"debug", LogLevel::Debug},
    };
    for (const auto& m : kMethods) {
        JSValue fn = checked(ctx, JS_NewCFunctionMagic(ctx, consoleMethod, m.name, 0, JS_CFUNC_generic_magic, int(m.level)));
        check(ctx, JS_DefinePropertyValueStr(ctx, console.get(), m.name, fn, JS_PROP_C_W_E));
    }
    // A namespace on the global: writable, configurable, not enumerable (WebIDL).
    Runtime::from(ctx).setGlobal("console", console.release());
}

} // namespace wr
