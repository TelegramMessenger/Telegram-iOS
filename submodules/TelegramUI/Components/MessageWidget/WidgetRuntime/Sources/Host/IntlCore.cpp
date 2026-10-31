#include "Sources/Host/Intl.h"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <iterator>
#include <new>
#include <memory>
#include <set>
#include <string_view>
#include <unordered_set>

#include "Sources/Host/HostState.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"

namespace wr::intl {

IntlState& intlState(JSContext* ctx) {
    return HostState::of(ctx).intl();
}

// ───────────── locale tags

namespace {

bool isAlpha(char c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}
bool isDigit(char c) {
    return c >= '0' && c <= '9';
}
bool isAlnum(char c) {
    return isAlpha(c) || isDigit(c);
}
bool allOf(std::string_view s, bool (*pred)(char)) {
    return std::all_of(s.begin(), s.end(), pred);
}
std::string lowered(std::string_view s) {
    std::string out(s);
    for (char& c : out) {
        c = char(std::tolower(uint8_t(c)));
    }
    return out;
}

/// ECMA-402 IsStructurallyValidLanguageTag: UTS 35's unicode_locale_id without duplicate variants or singletons. The
/// extensions' inner grammar is checked as "subtags of 2 to 8 alphanumerics"; ICU canonicalizes the rest.
bool isStructurallyValid(std::string_view tag) {
    std::vector<std::string_view> subtags;
    size_t start = 0;
    for (size_t i = 0; i <= tag.size(); i++) {
        if (i == tag.size() || tag[i] == '-') {
            subtags.push_back(tag.substr(start, i - start));
            start = i + 1;
        }
    }
    for (std::string_view s : subtags) {
        if (s.empty() || s.size() > 8 || !allOf(s, isAlnum)) {
            return false;
        }
    }
    size_t i = 0;
    // unicode_language_subtag: alpha{2,3} | alpha{5,8}
    if (!allOf(subtags[i], isAlpha) || subtags[i].size() < 2 || subtags[i].size() == 4) {
        return false;
    }
    i++;
    if (i < subtags.size() && subtags[i].size() == 4 && allOf(subtags[i], isAlpha)) {
        i++;  // script
    }
    if (i < subtags.size() && ((subtags[i].size() == 2 && allOf(subtags[i], isAlpha)) ||
                               (subtags[i].size() == 3 && allOf(subtags[i], isDigit)))) {
        i++;  // region
    }
    std::set<std::string> variants;
    while (i < subtags.size() && (subtags[i].size() >= 5 || (subtags[i].size() == 4 && isDigit(subtags[i][0])))) {
        if (!variants.insert(lowered(subtags[i])).second) {
            return false;
        }
        i++;
    }
    std::set<char> singletons;
    while (i < subtags.size()) {
        if (subtags[i].size() != 1) {
            return false;
        }
        const char singleton = char(std::tolower(uint8_t(subtags[i][0])));
        if (!singletons.insert(singleton).second) {
            return false;
        }
        i++;
        const size_t minimum = singleton == 'x' ? 1 : 2;
        size_t count = 0;
        while (i < subtags.size() && (singleton == 'x' || subtags[i].size() >= 2) && subtags[i].size() >= minimum) {
            i++;
            count++;
        }
        if (count == 0) {
            return false;
        }
        if (singleton == 'x') {
            return i == subtags.size();
        }
    }
    return true;
}

/// UTS 35's canonical case of a structurally valid tag, or nullopt: everything in lower case but a script (title case)
/// and a region (upper case) of the language identifier, the subtags before the first singleton. Aliases are not
/// replaced ("iw" stays "iw"): the host's glue reads the tag, and its Locale knows them.
std::optional<std::string> canonicalTag(std::string_view tag) {
    if (tag.size() > kMaxLocaleTag || !isStructurallyValid(tag)) {
        return std::nullopt;
    }
    std::string out = lowered(tag);
    size_t index = 0;
    for (size_t start = 0; start < out.size();) {
        size_t end = out.find('-', start);
        if (end == std::string::npos) {
            end = out.size();
        }
        const size_t length = end - start;
        if (index > 0 && length == 1) {
            break;  // a singleton: extensions and private use stay in lower case
        }
        if (index > 0 && length == 4 && isAlpha(out[start])) {
            out[start] = char(std::toupper(uint8_t(out[start])));
        } else if (index > 0 && length == 2) {
            out[start] = char(std::toupper(uint8_t(out[start])));
            out[start + 1] = char(std::toupper(uint8_t(out[start + 1])));
        }
        index++;
        start = end + 1;
    }
    return out;
}

JSValue arrayOf(JSContext* ctx, const std::vector<std::string>& list) {
    Value array = Value::adopt(ctx, checked(ctx, JS_NewArray(ctx)));
    for (uint32_t i = 0; i < list.size(); i++) {
        check(ctx, JS_DefinePropertyValueUint32(ctx, array.get(), i, JS_NewStringLen(ctx, list[i].data(), list[i].size()),
                                                JS_PROP_C_W_E));
    }
    return JS_DupValue(ctx, array.get());
}

} // namespace

std::vector<std::string> canonicalizeLocaleList(JSContext* ctx, JSValueConst locales) {
    std::vector<std::string> seen;
    std::unordered_set<std::string> distinct;
    if (JS_IsUndefined(locales)) {
        return seen;
    }
    auto add = [&](JSValueConst value) {
        if (!JS_IsString(value) && !JS_IsObject(value)) {
            throw TypeError{"Intl: a locale is neither a string nor an object."};
        }
        const String tag = String::fromJS(ctx, value);
        bool cut = false;
        const std::string bytes = tag.utf8Prefix(kMaxLocaleTag + 1, &cut);
        std::optional<std::string> canonical = cut ? std::nullopt : canonicalTag(bytes);
        if (!canonical) {
            throw RangeError{"Intl: incorrect locale information provided."};
        }
        if (distinct.insert(*canonical).second) {
            if (seen.size() == kMaxLocaleList) {
                throw RangeError{"Intl: the locale list has more than 128 distinct locales."};
            }
            seen.push_back(std::move(*canonical));
        }
    };
    if (JS_IsString(locales)) {
        add(locales);
        return seen;
    }
    Value object = Value::adopt(ctx, checked(ctx, JS_ToObject(ctx, locales)));
    int64_t length = 0;
    if (JS_GetLength(ctx, object.get(), &length) < 0) {
        throw Thrown{};
    }
    for (int64_t k = 0; k < length; k++) {
        if (k > int64_t(UINT32_MAX)) {
            throw RangeError{"Intl: the locale list is too long."};
        }
        JSAtom atom = JS_NewAtomUInt32(ctx, uint32_t(k));
        Atom owned = Atom::adopt(ctx, atom);
        const int present = JS_HasProperty(ctx, object.get(), atom);
        check(ctx, present);
        if (!present) {
            continue;
        }
        Value value = Value::adopt(ctx, checked(ctx, JS_GetProperty(ctx, object.get(), atom)));
        add(value.get());
    }
    return seen;
}

namespace {

// The keyword values this client sends to the glue (resolveLocale). Conservative on purpose: what Foundation formats
// on every iOS this app runs on, not what the newest one accepts, since an unknown value can trap inside Foundation.

/// The numbering systems with simple digit mappings of ECMA-402's first editions' table (today's lists more): numeric
/// systems every iOS this app runs on formats.
constexpr std::string_view kNumberingSystems[] = {"arab", "arabext", "bali", "beng", "deva", "fullwide", "gujr", "guru",
                                                  "hanidec", "khmr", "knda", "laoo", "latn", "limb", "mlym", "mong",
                                                  "mymr", "orya", "tamldec", "telu", "thai", "tibt"};
/// CLDR's calendars that Foundation's Calendar.Identifier has on iOS 15 (no dangi before iOS 18, no islamic-rgsa).
constexpr std::string_view kCalendars[] = {"buddhist", "chinese", "coptic", "ethioaa", "ethiopic", "gregory", "hebrew",
                                           "indian", "islamic", "islamic-civil", "islamic-tbla", "islamic-umalqura",
                                           "iso8601", "japanese", "persian", "roc"};
constexpr std::string_view kHourCycles[] = {"h11", "h12", "h23", "h24"};
/// CLDR's collations but the two ECMA-402 excludes (standard, search).
constexpr std::string_view kCollations[] = {"big5han", "compat", "dict", "direct", "ducet", "emoji", "eor", "gb2312",
                                            "phonebk", "phonetic", "pinyin", "reformed", "searchjl", "stroke", "trad",
                                            "unihan", "zhuyin"};
constexpr std::string_view kNumerics[] = {"true", "false"};
constexpr std::string_view kCaseFirstValues[] = {"upper", "lower", "false"};

template <size_t N>
bool listed(const std::string_view (&table)[N], std::string_view value) {
    return std::find(std::begin(table), std::end(table), value) != std::end(table);
}

/// Whether the keyword `key`-`value` ("true" for a key with no type) is one the constructor reads with a value sent.
bool keptKeyword(std::string_view key, std::string_view value, RelevantKeys keys) {
    const bool numbers = keys == RelevantKeys::NumberFormat || keys == RelevantKeys::DateTimeFormat ||
                         keys == RelevantKeys::RelativeTimeFormat;
    if (key == "nu") {
        return numbers && listed(kNumberingSystems, value);
    }
    if (keys == RelevantKeys::DateTimeFormat) {
        return (key == "ca" && listed(kCalendars, value)) || (key == "hc" && listed(kHourCycles, value));
    }
    if (keys == RelevantKeys::Collator) {
        return (key == "co" && listed(kCollations, value)) || (key == "kn" && listed(kNumerics, value)) ||
               (key == "kf" && listed(kCaseFirstValues, value));
    }
    return false;
}

/// `tag` (canonical, structurally valid) with its unicode extension reduced to the keywords keptKeyword keeps, sorted
/// by key, a "true" type dropped (UTS 35's canonical form), and of a repeated key the first kept occurrence (UTS 35 takes
/// the first occurrence; a dropped one leaves the key to a later one here, which is never less safe). Every other
/// extension and private use is dropped, as ECMA-402's resolved locale has none: Foundation read them as `@va=`, which
/// spoiled the glue's plural language key as `-u-` did, without a trap (follow-ups fix-wave review).
std::string withRelevantKeywords(std::string_view tag, RelevantKeys keys) {
    std::vector<std::string_view> subtags;
    for (size_t start = 0, i = 0; i <= tag.size(); i++) {
        if (i == tag.size() || tag[i] == '-') {
            subtags.push_back(tag.substr(start, i - start));
            start = i + 1;
        }
    }
    std::string language;
    std::vector<std::pair<std::string, std::string>> keywords;
    // Every singleton but `u` (and private use, after `x`) is dropped with its subtags: a resolved locale has none, and
    // Foundation took them as `@…=` keywords on the language key the glue reads plural rules from.
    char singleton = 0;
    std::string key, value;
    auto endKeyword = [&]() {
        if (key.empty()) {
            return;
        }
        const std::string type = value.empty() ? "true" : value;
        const bool repeated = std::any_of(keywords.begin(), keywords.end(), [&](const auto& k) { return k.first == key; });
        if (!repeated && keptKeyword(key, type, keys)) {
            keywords.emplace_back(key, type == "true" ? "" : type);
        }
        key.clear();
        value.clear();
    };
    for (std::string_view subtag : subtags) {
        if (singleton != 'x' && subtag.size() == 1) {
            endKeyword();
            singleton = subtag[0];
            continue;
        }
        if (singleton == 0) {
            language += (language.empty() ? "" : "-") + std::string(subtag);
        } else if (singleton != 'u') {
            continue;
        } else if (subtag.size() == 2) {
            endKeyword();
            key = std::string(subtag);
        } else if (!key.empty()) {
            value += (value.empty() ? "" : "-") + std::string(subtag);
        }
        // A type before any key is an attribute: no constructor reads one.
    }
    endKeyword();
    std::string out = language;
    if (!keywords.empty()) {
        std::sort(keywords.begin(), keywords.end());
        out += "-u";
        for (const auto& [k, v] : keywords) {
            out += "-" + k + (v.empty() ? "" : "-" + v);
        }
    }
    return out;
}

} // namespace

std::string resolveLocale(JSContext* ctx, const std::vector<std::string>& requested, RelevantKeys keys) {
    if (!requested.empty()) {
        return withRelevantKeywords(requested.front(), keys);
    }
    if (std::optional<std::string> host = canonicalTag(HostState::of(ctx).locale())) {
        return withRelevantKeywords(*host, keys);
    }
    return "en-US";
}

JSValue supportedLocales(JSContext* ctx, JSValueConst locales, JSValueConst options) {
    const std::vector<std::string> requested = canonicalizeLocaleList(ctx, locales);
    Value object = coerceOptionsToObject(ctx, options);
    getStringOption(ctx, object.get(), "localeMatcher", {"lookup", "best fit"});
    return arrayOf(ctx, requested);
}

// ───────────── options

void GivenOptions::addString(const char* name, std::string_view utf8) {
    m_members += m_members.empty() ? "" : ",";
    appendJSONString(m_members, name);
    m_members += ":";
    appendJSONString(m_members, utf8);
}

void GivenOptions::addNumber(JSContext* ctx, const char* name, double value) {
    m_members += m_members.empty() ? "" : ",";
    appendJSONString(m_members, name);
    m_members += ":";
    // A number option is finite after its range check; JS's own rendering of it, as JSON.stringify writes it.
    Value text = Value::adopt(ctx, checked(ctx, JS_ToString(ctx, JS_NewFloat64(ctx, value))));
    m_members += String::adopt(ctx, JS_DupValue(ctx, text.get())).utf8();
}

void GivenOptions::addBool(const char* name, bool value) {
    m_members += m_members.empty() ? "" : ",";
    appendJSONString(m_members, name);
    m_members += value ? ":true" : ":false";
}

JSText GivenOptions::json() const {
    JSText out(m_members.get_allocator());
    out.reserve(m_members.size() + 2);
    out += "{";
    out += m_members;
    out += "}";
    return out;
}

Value coerceOptionsToObject(JSContext* ctx, JSValueConst options) {
    if (JS_IsUndefined(options)) {
        return Value::adopt(ctx, checked(ctx, JS_NewObjectProto(ctx, JS_NULL)));
    }
    return Value::adopt(ctx, checked(ctx, JS_ToObject(ctx, options)));
}

std::optional<std::string> getStringOption(JSContext* ctx, JSValueConst options, const char* name,
                                           std::initializer_list<const char*> allowed, GivenOptions* given,
                                           size_t maxLength) {
    Value value = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, options, name)));
    if (JS_IsUndefined(value.get())) {
        return std::nullopt;
    }
    const String string = String::fromJS(ctx, value.get());
    size_t longest = maxLength;
    if (allowed.size()) {
        longest = 0;
        for (const char* a : allowed) {
            longest = std::max(longest, std::string_view(a).size());
        }
    }
    if (string.length() > longest) {
        throw RangeError{std::string("Intl: the value of ") + name + " is out of range."};
    }
    std::string utf8 = string.utf8ForParse();
    if (allowed.size() && std::none_of(allowed.begin(), allowed.end(), [&](const char* a) { return utf8 == a; })) {
        throw RangeError{std::string("Intl: the value of ") + name + " is out of range."};
    }
    if (given) {
        given->addString(name, utf8);
    }
    return utf8;
}

std::optional<bool> getBooleanOption(JSContext* ctx, JSValueConst options, const char* name, GivenOptions* given) {
    Value value = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, options, name)));
    if (JS_IsUndefined(value.get())) {
        return std::nullopt;
    }
    const bool b = JS_ToBool(ctx, value.get()) != 0;
    if (given) {
        given->addBool(name, b);
    }
    return b;
}

std::optional<int> getNumberOption(JSContext* ctx, JSValueConst options, const char* name, int min, int max,
                                   GivenOptions* given) {
    Value value = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, options, name)));
    if (JS_IsUndefined(value.get())) {
        return std::nullopt;
    }
    double number = 0;
    if (JS_ToFloat64(ctx, &number, value.get()) < 0) {
        throw Thrown{};
    }
    if (number != number || number < min || number > max) {
        throw RangeError{std::string("Intl: the value of ") + name + " is out of range."};
    }
    if (given) {
        given->addNumber(ctx, name, std::floor(number));
    }
    return int(number);
}

// ───────────── requests

void appendJSONString(JSText& out, std::string_view utf8) {
    static const char kHex[] = "0123456789abcdef";
    out += '"';
    for (char c : utf8) {
        const uint8_t byte = uint8_t(c);
        if (c == '"' || c == '\\') {
            out += '\\';
            out += c;
        } else if (byte < 0x20) {
            out += "\\u00";
            out += kHex[byte >> 4];
            out += kHex[byte & 15];
        } else {
            out += c;
        }
    }
    out += '"';
}

IntlRequest::IntlRequest(JSContext* ctx, const char* kind) : m_ctx(ctx), m_json(JSAllocator<char>(JS_GetRuntime(ctx))) {
    m_json += "{\"kind\":";
    appendJSONString(m_json, kind);
}

void IntlRequest::name(const char* name) {
    m_json += ',';
    appendJSONString(m_json, name);
    m_json += ':';
}

IntlRequest& IntlRequest::string(const char* name, std::string_view utf8) {
    this->name(name);
    appendJSONString(m_json, utf8);
    return *this;
}

IntlRequest& IntlRequest::string(const char* name, const String& value) {
    if (value.length() > kMaxIntlString) {
        throw RangeError{"Intl: the string is too long."};
    }
    return this->string(name, value.utf8ForParse());
}

IntlRequest& IntlRequest::number(const char* name, double value) {
    this->name(name);
    if (!std::isfinite(value)) {
        m_json += "null";
        return *this;
    }
    Value text = Value::adopt(m_ctx, checked(m_ctx, JS_ToString(m_ctx, JS_NewFloat64(m_ctx, value))));
    m_json += String::adopt(m_ctx, JS_DupValue(m_ctx, text.get())).utf8();
    return *this;
}

IntlRequest& IntlRequest::raw(const char* name, std::string_view json) {
    this->name(name);
    m_json += json;
    return *this;
}

std::string IntlRequest::send() {
    m_json += '}';
    std::string answer = Runtime::from(m_ctx).host().intl(std::string_view(m_json.data(), m_json.size()));
    if (answer.size() > kMaxIntlAnswer) {
        throw RangeError{"Intl: the result is too long."};
    }
    return answer;
}

JSValue answerString(JSContext* ctx, std::string_view answer) {
    return String::fromUTF8(ctx, answer).toJS(ctx);
}

Value answerJSON(JSContext* ctx, const std::string& answer, bool array) {
    if (!answer.empty()) {
        Value parsed = Value::adopt(ctx, JS_ParseJSON(ctx, answer.c_str(), answer.size(), "<intl>"));
        if (JS_IsException(parsed.get())) {
            // Not the widget's error: dropped, unless the widget is stopping.
            if (Runtime::from(ctx).stopReason() != StopReason::None) {
                throw Thrown{};
            }
            JS_FreeValue(ctx, JS_GetException(ctx));
        } else if (array ? JS_IsArray(parsed.get()) : JS_IsObject(parsed.get()) && !JS_IsArray(parsed.get())) {
            return parsed;
        }
    }
    return Value::adopt(ctx, checked(ctx, array ? JS_NewArray(ctx) : JS_NewObject(ctx)));
}

namespace {

/// `object`'s own data property `name`, or nullopt.
std::optional<Value> ownValue(JSContext* ctx, JSValueConst object, const char* name) {
    if (!JS_IsObject(object)) {
        return std::nullopt;
    }
    const Atom atom = Atom::fromUTF8(ctx, name);
    JSPropertyDescriptor desc{};
    const int found = JS_GetOwnProperty(ctx, &desc, object, atom.get());
    check(ctx, found);
    if (!found) {
        return std::nullopt;
    }
    JS_FreeValue(ctx, desc.getter);
    JS_FreeValue(ctx, desc.setter);
    return Value::adopt(ctx, desc.value);
}

} // namespace

JSValue mergedOptions(JSContext* ctx, JSValueConst answer, JSValueConst ours, std::initializer_list<const char*> keys) {
    Value o = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
    for (const char* key : keys) {
        std::optional<Value> value = ownValue(ctx, answer, key);
        if (!value) {
            value = ownValue(ctx, ours, key);
        }
        if (value) {
            check(ctx, JS_DefinePropertyValueStr(ctx, o.get(), key, value->release(), JS_PROP_C_W_E));
        }
    }
    return o.release();
}

// ───────────── the classes

int optionIndex(const std::optional<std::string>& value, std::initializer_list<const char*> allowed, int fallback) {
    if (!value) {
        return fallback;
    }
    int index = 0;
    for (const char* a : allowed) {
        if (*value == a) {
            return index;
        }
        index++;
    }
    return fallback;
}

const char* optionAt(std::initializer_list<const char*> allowed, size_t index) {
    return *(allowed.begin() + std::ptrdiff_t(index));
}

void defineString(JSContext* ctx, JSValueConst object, const char* name, std::string_view value) {
    check(ctx, JS_DefinePropertyValueStr(ctx, object, name, JS_NewStringLen(ctx, value.data(), value.size()), JS_PROP_C_W_E));
}

void defineInt(JSContext* ctx, JSValueConst object, const char* name, int value) {
    check(ctx, JS_DefinePropertyValueStr(ctx, object, name, JS_NewInt32(ctx, value), JS_PROP_C_W_E));
}

void defineBool(JSContext* ctx, JSValueConst object, const char* name, bool value) {
    check(ctx, JS_DefinePropertyValueStr(ctx, object, name, JS_NewBool(ctx, value), JS_PROP_C_W_E));
}

bool isUnicodeType(std::string_view type) {
    size_t run = 0;
    for (size_t i = 0; i <= type.size(); i++) {
        if (i == type.size() || type[i] == '-') {
            if (run < 3 || run > 8) {
                return false;
            }
            run = 0;
        } else if (std::isalnum(uint8_t(type[i]))) {
            run++;
        } else {
            return false;
        }
    }
    return true;
}

JSClassID registerIntlClass(JSContext* ctx, IntlClass which, const char* name, JSClassFinalizer* finalizer,
                            JSClassGCMark* mark) {
    IntlState& state = intlState(ctx);
    JSClassID& id = state.classIds[size_t(which)];
    if (!id) {
        JSClassID fresh = 0;
        JS_NewClassID(state.rt, &fresh);
        JSClassDef def{};
        def.class_name = name;
        def.finalizer = finalizer;
        def.gc_mark = mark;
        if (JS_NewClass(state.rt, fresh, &def) < 0) {
            throw std::bad_alloc();
        }
        id = fresh;
    }
    return id;
}

namespace {

JSValue supportedLocalesOf(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        return supportedLocales(ctx, argc > 0 ? argv[0] : JS_UNDEFINED, argc > 1 ? argv[1] : JS_UNDEFINED);
    });
}

const JSCFunctionListEntry kConstructorStatics[] = {
    JS_CFUNC_DEF("supportedLocalesOf", 1, supportedLocalesOf),
};

} // namespace

void defineIntlConstructor(JSContext* ctx, JSValueConst intl, JSClassID id, const char* name, JSCFunction* constructor,
                           int length, const JSCFunctionListEntry* prototypeMembers, int memberCount) {
    Value proto = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
    check(ctx, JS_SetPropertyFunctionList(ctx, proto.get(), prototypeMembers, memberCount));
    Value ctor = Value::adopt(ctx, checked(ctx, JS_NewCFunction2(ctx, constructor, name, length, JS_CFUNC_constructor_or_func, 0)));
    check(ctx, JS_SetPropertyFunctionList(ctx, ctor.get(), kConstructorStatics, int(std::size(kConstructorStatics))));
    check(ctx, JS_SetConstructor(ctx, ctor.get(), proto.get()));
    JS_SetClassProto(ctx, id, JS_DupValue(ctx, proto.get()));
    check(ctx, JS_DefinePropertyValueStr(ctx, intl, name, JS_DupValue(ctx, ctor.get()), JS_PROP_WRITABLE | JS_PROP_CONFIGURABLE));
}

Value prototypeFromConstructor(JSContext* ctx, JSValueConst newTarget, JSClassID id) {
    if (JS_IsObject(newTarget)) {
        Value proto = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, newTarget, "prototype")));
        if (JS_IsObject(proto.get())) {
            return proto;
        }
    }
    return Value::adopt(ctx, checked(ctx, JS_GetClassProto(ctx, id)));
}

JSValue boundIntlFunction(JSContext* ctx, JSCFunctionData* function, int length, JSValueConst target) {
    JSValueConst data[] = {target};
    return checked(ctx, JS_NewCFunctionData2(ctx, function, "", length, 0, 1, data));
}

Text16 utf16Of(JSContext* ctx, const String& string) {
    const uint32_t length = string.length();
    if (length > kMaxIntlString) {
        throw RangeError{"Intl: the string is too long."};
    }
    Text16 out{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
    const JSStringView view = string.view();
    if (view.utf16) {
        out.assign(view.utf16, view.utf16 + length);
    } else if (view.latin1) {
        out.assign(view.latin1, view.latin1 + length);
    }
    return out;
}

// ───────────── Intl

namespace {

JSValue getCanonicalLocales(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        return arrayOf(ctx, canonicalizeLocaleList(ctx, argc > 0 ? argv[0] : JS_UNDEFINED));
    });
}

const JSCFunctionListEntry kIntlFunctions[] = {
    JS_CFUNC_DEF("getCanonicalLocales", 1, getCanonicalLocales),
    JS_PROP_STRING_DEF("[Symbol.toStringTag]", "Intl", JS_PROP_CONFIGURABLE),
};

} // namespace

JSValue intlObject(JSContext* ctx) {
    IntlState& state = intlState(ctx);
    if (state.intl.isUndefined()) {
        Value intl = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
        check(ctx, JS_SetPropertyFunctionList(ctx, intl.get(), kIntlFunctions, int(std::size(kIntlFunctions))));
        defineNumberFormat(ctx, intl.get());
        defineDateTimeFormat(ctx, intl.get());
        defineTextFormats(ctx, intl.get());
        state.intl.set(state.rt, JS_DupValue(ctx, intl.get()));
    }
    return JS_DupValue(ctx, state.intl.value);
}

void installIntl(JSContext* ctx) {
    installNumberOverrides(ctx);
    installDateOverrides(ctx);
    installStringOverrides(ctx);
    Runtime::from(ctx).defineLazyGlobal("Intl", [](JSContext* ctx) -> JSValue {
        try {
            return intlObject(ctx);
        } catch (...) {
            return rethrowAsJS(ctx);
        }
    });
}

} // namespace wr::intl
