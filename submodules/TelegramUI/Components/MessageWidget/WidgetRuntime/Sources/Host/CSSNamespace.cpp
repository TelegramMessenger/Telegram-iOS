#include "Sources/Host/CSSNamespace.h"

#include "Sources/Host/CSSSupports.h"
#include "Sources/Host/Encoding.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"

namespace wr {

namespace {

void appendHexEscape(Text16& out, uint32_t c) {
    const char* const digits = "0123456789abcdef";
    char hex[8];
    int n = 0;
    do {
        hex[n++] = digits[c & 0xF];
        c >>= 4;
    } while (c);
    out.push_back(u'\\');
    while (n) {
        out.push_back(char16_t(hex[--n]));
    }
    out.push_back(u' ');
}

/// CSSOM §2.1 "serialize an identifier", over UTF-16 units (a unit of a surrogate pair, or a lone one, is >= U+0080 and
/// stays as it is, which is what the code point rule gives).
JSValue escapeIdentifier(JSContext* ctx, const String& ident) {
    const uint32_t length = ident.length();
    Text16 out{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
    out.reserve(length);
    const char16_t first = length ? ident.at(0) : 0;
    for (uint32_t i = 0; i < length; i++) {
        const char16_t c = ident.at(i);
        const bool digit = c >= u'0' && c <= u'9';
        if (c == 0) {
            out.push_back(0xFFFD);
        } else if ((c >= 0x01 && c <= 0x1F) || c == 0x7F || (i == 0 && digit) || (i == 1 && digit && first == u'-')) {
            appendHexEscape(out, c);
        } else if (i == 0 && c == u'-' && length == 1) {
            out.push_back(u'\\');
            out.push_back(c);
        } else if (c >= 0x80 || c == u'-' || c == u'_' || digit || (c >= u'A' && c <= u'Z') || (c >= u'a' && c <= u'z')) {
            out.push_back(c);
        } else {
            out.push_back(u'\\');
            out.push_back(c);
        }
    }
    return String::fromUTF16(ctx, out.data(), out.size()).toJS(ctx);
}

JSValue escape(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        if (argc < 1) {
            throw TypeError{"CSS.escape: 1 argument required, but only 0 present."};
        }
        return escapeIdentifier(ctx, String::fromJS(ctx, argv[0]));
    });
}

/// WebIDL's overloads by argument count: supports(conditionText), supports(property, value).
JSValue supports(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        if (argc < 1) {
            throw TypeError{"CSS.supports: 1 argument required, but only 0 present."};
        }
        if (argc == 1) {
            return JS_NewBool(ctx, css::supportsCondition(ctx, String::fromJS(ctx, argv[0])));
        }
        const String property = String::fromJS(ctx, argv[0]);
        const String value = String::fromJS(ctx, argv[1]);
        return JS_NewBool(ctx, css::supportsDeclarationText(ctx, property, value));
    });
}

const JSCFunctionListEntry kClassString[] = {
    JS_PROP_STRING_DEF("[Symbol.toStringTag]", "CSS", JS_PROP_CONFIGURABLE),
};

JSValue makeCSS(JSContext* ctx) {
    try {
        Value css = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
        check(ctx, JS_DefinePropertyValueStr(ctx, css.get(), "escape", checked(ctx, JS_NewCFunction(ctx, escape, "escape", 1)), JS_PROP_C_W_E));
        check(ctx, JS_DefinePropertyValueStr(ctx, css.get(), "supports", checked(ctx, JS_NewCFunction(ctx, supports, "supports", 1)), JS_PROP_C_W_E));
        check(ctx, JS_SetPropertyFunctionList(ctx, css.get(), kClassString, 1));
        return css.release();
    } catch (...) {
        return rethrowAsJS(ctx);
    }
}

} // namespace

void installCSSNamespace(JSContext* ctx) {
    Runtime::from(ctx).defineLazyGlobal("CSS", makeCSS);
}

} // namespace wr
