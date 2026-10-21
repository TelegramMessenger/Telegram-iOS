#include "Sources/Host/Intl.h"

#include <algorithm>
#include <cctype>
#include <iterator>
#include <climits>
#include <new>
#include <memory>
#include <set>
#include <string_view>
#include <unordered_set>

#include "Sources/Host/HostState.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"
#include "Sources/Support/Work.h"

namespace wr::intl {

// ───────────── the ICU cache

IntlCache::~IntlCache() {
    for (Entry& entry : m_entries) {
        entry.close(entry.handle);
    }
}

void* IntlCache::find(const std::string& key) {
    for (auto it = m_entries.begin(); it != m_entries.end(); ++it) {
        if (it->key == key) {
            m_entries.splice(m_entries.begin(), m_entries, it);
            return m_entries.front().handle;
        }
    }
    return nullptr;
}

void IntlCache::insert(const std::string& key, void* handle, void (*close)(void*)) {
    m_entries.push_front(Entry{key, handle, close});
    while (m_entries.size() > kIntlCacheSize) {
        m_entries.back().close(m_entries.back().handle);
        m_entries.pop_back();
    }
}

void IntlCache::chargeOpen(JSContext* ctx) {
    charge(ctx, work::kIntlOpen);
}

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

/// The canonical form ICU gives a structurally valid tag, or nullopt.
std::optional<std::string> canonicalTag(std::string_view tag) {
    if (tag.size() > kMaxLocaleTag || !isStructurallyValid(tag)) {
        return std::nullopt;
    }
    const std::string input(tag);
    char localeID[ULOC_FULLNAME_CAPACITY + 1] = {};
    int32_t parsed = 0;
    UErrorCode status = U_ZERO_ERROR;
    uloc_forLanguageTag(input.c_str(), localeID, ULOC_FULLNAME_CAPACITY, &parsed, &status);
    if (U_FAILURE(status) || status == U_STRING_NOT_TERMINATED_WARNING || size_t(parsed) != input.size()) {
        return std::nullopt;
    }
    char out[ULOC_FULLNAME_CAPACITY + 1] = {};
    status = U_ZERO_ERROR;
    const int32_t length = uloc_toLanguageTag(localeID, out, ULOC_FULLNAME_CAPACITY, true, &status);
    if (U_FAILURE(status) || status == U_STRING_NOT_TERMINATED_WARNING || length <= 0) {
        return std::nullopt;
    }
    return std::string(out, size_t(length));
}

/// ICU's available locales as canonical tags, once per process.
const std::set<std::string>& availableLocales() {
    static const std::set<std::string> available = [] {
        std::set<std::string> out;
        UErrorCode status = U_ZERO_ERROR;
        // With the legacy aliases: uloc_getAvailable lacks zh_TW and zh_HK, which then resolved to zh (Simplified).
        std::unique_ptr<UEnumeration, void (*)(UEnumeration*)> all(
            uloc_openAvailableByType(ULOC_AVAILABLE_WITH_LEGACY_ALIASES, &status), uenum_close);
        int32_t idLength = 0;
        while (U_SUCCESS(status) && all) {
            const char* id = uenum_next(all.get(), &idLength, &status);
            if (!id || U_FAILURE(status)) {
                break;
            }
            char tag[ULOC_FULLNAME_CAPACITY + 1] = {};
            UErrorCode tagStatus = U_ZERO_ERROR;
            const int32_t length = uloc_toLanguageTag(id, tag, ULOC_FULLNAME_CAPACITY, false, &tagStatus);
            if (U_SUCCESS(tagStatus) && tagStatus != U_STRING_NOT_TERMINATED_WARNING && length > 0) {
                out.insert(std::string(tag, size_t(length)));
            }
        }
        return out;
    }();
    return available;
}

/// The tag without its unicode extension sequences ("-u-…" up to the next singleton).
std::string withoutUnicodeExtensions(const std::string& tag) {
    std::string out;
    size_t start = 0;
    bool inUnicode = false;
    for (size_t i = 0; i <= tag.size(); i++) {
        if (i == tag.size() || tag[i] == '-') {
            const std::string_view subtag(tag.data() + start, i - start);
            if (subtag.size() == 1) {
                inUnicode = (subtag[0] == 'u' || subtag[0] == 'U');
            }
            if (subtag == "x" || subtag == "X") {
                out += tag.substr(start - (start ? 1 : 0));
                return out;
            }
            if (!inUnicode) {
                out += (out.empty() ? "" : "-");
                out += subtag;
            }
            start = i + 1;
        }
    }
    return out;
}

/// ECMA-402 BestAvailableLocale.
std::optional<std::string> bestAvailable(std::string candidate) {
    const std::set<std::string>& available = availableLocales();
    for (;;) {
        if (available.count(candidate)) {
            return candidate;
        }
        size_t pos = candidate.rfind('-');
        if (pos == std::string::npos) {
            return std::nullopt;
        }
        if (pos >= 2 && candidate[pos - 2] == '-') {
            pos -= 2;
        }
        candidate.resize(pos);
    }
}

std::optional<std::string> lookup(const std::vector<std::string>& requested) {
    for (const std::string& tag : requested) {
        if (std::optional<std::string> found = bestAvailable(withoutUnicodeExtensions(tag))) {
            return found;
        }
    }
    return std::nullopt;
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
        charge(ctx, work::kNodeVisit);
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

std::string resolveLocale(JSContext* ctx, const std::vector<std::string>& requested) {
    if (std::optional<std::string> found = lookup(requested)) {
        return *found;
    }
    if (std::optional<std::string> host = canonicalTag(HostState::of(ctx).locale())) {
        if (std::optional<std::string> found = lookup({*host})) {
            return *found;
        }
    }
    return "en-US";
}

JSValue supportedLocales(JSContext* ctx, JSValueConst locales, JSValueConst options) {
    const std::vector<std::string> requested = canonicalizeLocaleList(ctx, locales);
    Value object = coerceOptionsToObject(ctx, options);
    getStringOption(ctx, object.get(), "localeMatcher", {"lookup", "best fit"});
    std::vector<std::string> supported;
    for (const std::string& tag : requested) {
        if (bestAvailable(withoutUnicodeExtensions(tag))) {
            supported.push_back(tag);
        }
    }
    return arrayOf(ctx, supported);
}

// ───────────── options

Value coerceOptionsToObject(JSContext* ctx, JSValueConst options) {
    if (JS_IsUndefined(options)) {
        return Value::adopt(ctx, checked(ctx, JS_NewObjectProto(ctx, JS_NULL)));
    }
    return Value::adopt(ctx, checked(ctx, JS_ToObject(ctx, options)));
}

std::optional<std::string> getStringOption(JSContext* ctx, JSValueConst options, const char* name,
                                           std::initializer_list<const char*> allowed, size_t maxLength) {
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
    std::string utf8 = string.utf8();
    if (allowed.size() && std::none_of(allowed.begin(), allowed.end(), [&](const char* a) { return utf8 == a; })) {
        throw RangeError{std::string("Intl: the value of ") + name + " is out of range."};
    }
    return utf8;
}

std::optional<bool> getBooleanOption(JSContext* ctx, JSValueConst options, const char* name) {
    Value value = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, options, name)));
    if (JS_IsUndefined(value.get())) {
        return std::nullopt;
    }
    return JS_ToBool(ctx, value.get()) != 0;
}

std::optional<int> getNumberOption(JSContext* ctx, JSValueConst options, const char* name, int min, int max) {
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
    return int(number);
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
    chargeScan(ctx, length);
    Text16 out{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
    const JSStringView view = string.view();
    if (view.utf16) {
        out.assign(view.utf16, view.utf16 + length);
    } else if (view.latin1) {
        out.assign(view.latin1, view.latin1 + length);
    }
    return out;
}

bool icuAvailable() {
    // The weak imports of ICU.h, every one: a null address is a function this iOS's libicucore lacks.
    static const bool available = [] {
        const void* const functions[] = {
        reinterpret_cast<const void*>(&uloc_forLanguageTag),
        reinterpret_cast<const void*>(&uloc_toLanguageTag),
        reinterpret_cast<const void*>(&uloc_openAvailableByType),
        reinterpret_cast<const void*>(&ufieldpositer_open),
        reinterpret_cast<const void*>(&ufieldpositer_close),
        reinterpret_cast<const void*>(&ufieldpositer_next),
        reinterpret_cast<const void*>(&unumf_openForSkeletonAndLocale),
        reinterpret_cast<const void*>(&unumf_close),
        reinterpret_cast<const void*>(&unumf_openResult),
        reinterpret_cast<const void*>(&unumf_closeResult),
        reinterpret_cast<const void*>(&unumf_formatDouble),
        reinterpret_cast<const void*>(&unumf_formatDecimal),
        reinterpret_cast<const void*>(&unumf_resultToString),
        reinterpret_cast<const void*>(&unumf_resultGetAllFieldPositions),
        reinterpret_cast<const void*>(&ucurr_getDefaultFractionDigits),
        reinterpret_cast<const void*>(&unumsys_open),
        reinterpret_cast<const void*>(&unumsys_openByName),
        reinterpret_cast<const void*>(&unumsys_close),
        reinterpret_cast<const void*>(&unumsys_getName),
        reinterpret_cast<const void*>(&unumsys_isAlgorithmic),
        reinterpret_cast<const void*>(&uloc_setKeywordValue),
        reinterpret_cast<const void*>(&uenum_close),
        reinterpret_cast<const void*>(&uenum_next),
        reinterpret_cast<const void*>(&ucal_openTimeZones),
        reinterpret_cast<const void*>(&ucal_getCanonicalTimeZoneID),
        reinterpret_cast<const void*>(&ucal_getType),
        reinterpret_cast<const void*>(&udat_open),
        reinterpret_cast<const void*>(&udat_close),
        reinterpret_cast<const void*>(&udat_format),
        reinterpret_cast<const void*>(&udat_formatForFields),
        reinterpret_cast<const void*>(&udat_toPattern),
        reinterpret_cast<const void*>(&udat_getCalendar),
        reinterpret_cast<const void*>(&udatpg_open),
        reinterpret_cast<const void*>(&udatpg_close),
        reinterpret_cast<const void*>(&udatpg_getBestPatternWithOptions),
        reinterpret_cast<const void*>(&udatpg_getSkeleton),
        reinterpret_cast<const void*>(&udatpg_getDefaultHourCycle),
        reinterpret_cast<const void*>(&uplrules_openForType),
        reinterpret_cast<const void*>(&uplrules_close),
        reinterpret_cast<const void*>(&uplrules_selectFormatted),
        reinterpret_cast<const void*>(&uplrules_getKeywords),
        reinterpret_cast<const void*>(&ureldatefmt_open),
        reinterpret_cast<const void*>(&ureldatefmt_close),
        reinterpret_cast<const void*>(&ureldatefmt_formatNumeric),
        reinterpret_cast<const void*>(&ureldatefmt_format),
        reinterpret_cast<const void*>(&ulistfmt_openForType),
        reinterpret_cast<const void*>(&ulistfmt_close),
        reinterpret_cast<const void*>(&ulistfmt_format),
        reinterpret_cast<const void*>(&ucol_open),
        reinterpret_cast<const void*>(&ucol_close),
        reinterpret_cast<const void*>(&ucol_strcoll),
        reinterpret_cast<const void*>(&ucol_setAttribute),
        reinterpret_cast<const void*>(&ucol_getAttribute),
        };
        return std::all_of(std::begin(functions), std::end(functions), [](const void* f) { return f != nullptr; });
    }();
    return available;
}

bool isSupportedNumberingSystem(const std::string& name) {
    UErrorCode status = U_ZERO_ERROR;
    std::unique_ptr<UNumberingSystem, void (*)(UNumberingSystem*)> numbering(unumsys_openByName(name.c_str(), &status),
                                                                         unumsys_close);
    return U_SUCCESS(status) && numbering && !unumsys_isAlgorithmic(numbering.get());
}

std::string toICULocale(const std::string& tag) {
    char id[ULOC_FULLNAME_CAPACITY + 1] = {};
    int32_t parsed = 0;
    UErrorCode status = U_ZERO_ERROR;
    uloc_forLanguageTag(tag.c_str(), id, ULOC_FULLNAME_CAPACITY, &parsed, &status);
    return U_SUCCESS(status) && status != U_STRING_NOT_TERMINATED_WARNING ? std::string(id) : std::string("en_US");
}

FieldIterator openFieldIterator() {
    UErrorCode status = U_ZERO_ERROR;
    FieldIterator fields(ufieldpositer_open(&status), ufieldpositer_close);
    if (U_FAILURE(status) || !fields) {
        throw RangeError{"Intl: ICU failed."};
    }
    return fields;
}

JSValue partsFromFields(JSContext* ctx, const Text16& text, UFieldPositionIterator* fields, PartType type,
                        const void* context) {
    Vector<int8_t> fieldAt{JSAllocator<int8_t>(JS_GetRuntime(ctx))};
    Vector<int32_t> spanAt{JSAllocator<int32_t>(JS_GetRuntime(ctx))};
    fieldAt.assign(text.size(), -1);
    spanAt.assign(text.size(), INT32_MAX);
    int32_t begin = 0, end = 0;
    for (int32_t field; (field = ufieldpositer_next(fields, &begin, &end)) >= 0;) {
        charge(ctx, work::kNodeVisit);
        for (int32_t i = std::max(begin, 0); i < end && size_t(i) < text.size(); i++) {
            if (end - begin < spanAt[size_t(i)]) {
                fieldAt[size_t(i)] = int8_t(field);
                spanAt[size_t(i)] = end - begin;
            }
        }
    }
    Value parts = Value::adopt(ctx, checked(ctx, JS_NewArray(ctx)));
    uint32_t count = 0;
    for (size_t start = 0; start < text.size();) {
        size_t stop = start + 1;
        while (stop < text.size() && fieldAt[stop] == fieldAt[start]) {
            stop++;
        }
        const std::u16string_view value(text.data() + start, stop - start);
        Value part = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
        check(ctx, JS_DefinePropertyValueStr(ctx, part.get(), "type", JS_NewString(ctx, type(fieldAt[start], value, context)),
                                             JS_PROP_C_W_E));
        check(ctx, JS_DefinePropertyValueStr(ctx, part.get(), "value", String::fromUTF16(ctx, value.data(), value.size()).toJS(ctx),
                                             JS_PROP_C_W_E));
        check(ctx, JS_DefinePropertyValueUint32(ctx, parts.get(), count++, part.release(), JS_PROP_C_W_E));
        start = stop;
    }
    return parts.release();
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
    if (!icuAvailable()) {
        // An ICU without what Intl calls: no Intl and the engine's own toLocaleString, rather than a failed launch.
        return;
    }
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
