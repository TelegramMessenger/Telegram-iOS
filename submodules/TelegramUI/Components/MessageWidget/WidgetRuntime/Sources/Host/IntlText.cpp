// Intl.PluralRules, RelativeTimeFormat, ListFormat and Collator, and String.prototype.localeCompare (V5b plan, Task 4;
// ECMA-402 §16, §17, §13, §10). Each reads its options in ECMA-402's order and keeps the ones given; selecting,
// formatting and comparing are the host's `plural`, `relative`, `list` and `compare` requests (Sources/Host/Intl.h),
// made after every argument is converted. Locale-sensitive case mapping stays the system ICU's (u_strToUpper, public).
#include <array>
#include <cctype>
#include <cmath>
#include <cstdlib>
#include <memory>
#include <string_view>
#include <tuple>

#include "Sources/Host/ICU.h"
#include "Sources/Host/Intl.h"
#include "Sources/Runtime/Runtime.h"

namespace wr::intl {

namespace {

const std::initializer_list<const char*> kMatchers = {"lookup", "best fit"};
const std::initializer_list<const char*> kPluralTypes = {"cardinal", "ordinal"};
const std::initializer_list<const char*> kWidths = {"long", "short", "narrow"};
const std::initializer_list<const char*> kNumerics = {"always", "auto"};
const std::initializer_list<const char*> kListTypes = {"conjunction", "disjunction", "unit"};
const std::initializer_list<const char*> kUsages = {"sort", "search"};
const std::initializer_list<const char*> kCaseFirsts = {"upper", "lower", "false"};
const std::initializer_list<const char*> kSensitivities = {"base", "accent", "case", "variant"};
const char* const kPluralCategories[] = {"zero", "one", "two", "few", "many", "other"};
/// Numbers that land in every category CLDR's plural rules have, in every language Telegram ships (zero, one and two
/// are small integers; few and many are 3 to 19, the teens, 21 to 23 and 101 to 111 for the languages that count them;
/// French "many" is a million; fractions are "few" or "many" where the rules look at them).
const double kPluralSamples[] = {0, 1, 2, 3, 4, 5, 6, 7, 11, 12, 13, 21, 22, 23, 100, 101, 102, 103, 111, 1000000, 0.1, 0.5, 1.5};

/// ECMA-402 GetOptionsObject: a null-prototype object for undefined, the object itself, else a TypeError.
Value getOptionsObject(JSContext* ctx, JSValueConst options) {
    if (JS_IsUndefined(options)) {
        return Value::adopt(ctx, checked(ctx, JS_NewObjectProto(ctx, JS_NULL)));
    }
    if (!JS_IsObject(options)) {
        throw TypeError{"Intl: the options are not an object."};
    }
    return Value::dup(ctx, options);
}

void requireNew(JSValueConst newTarget, const char* name) {
    if (JS_IsUndefined(newTarget)) {
        throw TypeError{std::string("Intl.") + name + " must be called with new."};
    }
}

JSClassID classOf(JSContext* ctx, IntlClass which) {
    return intlState(ctx).classIds[size_t(which)];
}

std::string_view optsOf(const IntlObjectBase& object) {
    return std::string_view(object.opts.data(), object.opts.size());
}

// ───────────── PluralRules

struct PluralRulesObject : IntlObjectBase {
    PluralRulesObject(std::string_view locale, JSText opts, uint8_t type, const DigitOptions& digits)
        : IntlObjectBase(locale, std::move(opts)), type(type), digits(digits) {}
    uint8_t type = 0;
    DigitOptions digits;
};

JSValue pluralRulesConstruct(JSContext* ctx, JSValueConst newTarget, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        requireNew(newTarget, "PluralRules");
        const JSClassID id = classOf(ctx, IntlClass::PluralRules);
        Value proto = prototypeFromConstructor(ctx, newTarget, id);
        GivenOptions given(ctx);
        const std::vector<std::string> requested = canonicalizeLocaleList(ctx, argc > 0 ? argv[0] : JS_UNDEFINED);
        Value options = coerceOptionsToObject(ctx, argc > 1 ? argv[1] : JS_UNDEFINED);
        getStringOption(ctx, options.get(), "localeMatcher", kMatchers);
        const uint8_t type = uint8_t(optionIndex(getStringOption(ctx, options.get(), "type", kPluralTypes, &given), kPluralTypes, 0));
        DigitOptions digits;
        readDigitOptions(ctx, options.get(), 0, 3, Notation::Standard, digits, &given);
        const std::string locale = resolveLocale(ctx, requested, RelevantKeys::None);
        return createIntlObject<PluralRulesObject>(ctx, proto.get(), id, locale, given.json(), type, digits).release();
    });
}

/// The host's category for `n` with the options `opts`.
std::string pluralCategory(JSContext* ctx, std::string_view locale, std::string_view opts, double n) {
    IntlRequest request(ctx, "plural");
    request.string("locale", locale).raw("opts", opts).number("value", n);
    std::string category = request.send();
    return category.empty() ? "other" : category;
}

JSValue pluralRulesSelect(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        const PluralRulesObject& pr = intlReceiver<PluralRulesObject>(ctx, thisVal, classOf(ctx, IntlClass::PluralRules),
                                                                       "Intl.PluralRules.prototype.select");
        double n = 0;
        if (JS_ToFloat64(ctx, &n, argc > 0 ? argv[0] : JS_UNDEFINED) < 0) {
            throw Thrown{};
        }
        if (!std::isfinite(n)) {
            return JS_NewString(ctx, "other");
        }
        return answerString(ctx, pluralCategory(ctx, pr.locale, optsOf(pr), n));
    });
}

JSValue pluralRulesResolvedOptions(JSContext* ctx, JSValueConst thisVal, int, JSValueConst*) {
    return glue(ctx, [&]() -> JSValue {
        const PluralRulesObject& pr = intlReceiver<PluralRulesObject>(ctx, thisVal, classOf(ctx, IntlClass::PluralRules),
                                                                       "Intl.PluralRules.prototype.resolvedOptions");
        // The host has no list of categories: the ones its rules give the samples, under the type alone (the digit
        // options change which numbers land where, not which categories there are).
        JSText typeOnly(pr.opts.get_allocator());
        typeOnly += "{\"type\":";
        appendJSONString(typeOnly, optionAt(kPluralTypes, pr.type));
        typeOnly += "}";
        std::array<bool, 6> present{};
        present[5] = true;
        for (double sample : kPluralSamples) {
            const std::string category = pluralCategory(ctx, pr.locale, std::string_view(typeOnly.data(), typeOnly.size()), sample);
            for (size_t i = 0; i < present.size(); i++) {
                present[i] = present[i] || category == kPluralCategories[i];
            }
        }
        Value o = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
        defineString(ctx, o.get(), "locale", pr.locale);
        defineString(ctx, o.get(), "type", optionAt(kPluralTypes, pr.type));
        defineDigitCounts(ctx, o.get(), pr.digits);
        Value categories = Value::adopt(ctx, checked(ctx, JS_NewArray(ctx)));
        uint32_t count = 0;
        for (size_t i = 0; i < present.size(); i++) {
            if (present[i]) {
                check(ctx, JS_DefinePropertyValueUint32(ctx, categories.get(), count++, JS_NewString(ctx, kPluralCategories[i]), JS_PROP_C_W_E));
            }
        }
        check(ctx, JS_DefinePropertyValueStr(ctx, o.get(), "pluralCategories", categories.release(), JS_PROP_C_W_E));
        defineRoundingOptions(ctx, o.get(), pr.digits);
        return o.release();
    });
}

const JSCFunctionListEntry kPluralRulesPrototype[] = {
    JS_CFUNC_DEF("select", 1, pluralRulesSelect),
    JS_CFUNC_DEF("resolvedOptions", 0, pluralRulesResolvedOptions),
    JS_PROP_STRING_DEF("[Symbol.toStringTag]", "Intl.PluralRules", JS_PROP_CONFIGURABLE),
};

// ───────────── RelativeTimeFormat

struct RelativeTimeFormatObject : IntlObjectBase {
    RelativeTimeFormatObject(std::string_view locale, JSText opts, uint8_t style, uint8_t numeric)
        : IntlObjectBase(locale, std::move(opts)), style(style), numeric(numeric) {}
    char numberingSystem[16] = "latn";
    uint8_t style = 0;
    uint8_t numeric = 0;
};

JSValue relativeTimeConstruct(JSContext* ctx, JSValueConst newTarget, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        requireNew(newTarget, "RelativeTimeFormat");
        const JSClassID id = classOf(ctx, IntlClass::RelativeTimeFormat);
        Value proto = prototypeFromConstructor(ctx, newTarget, id);
        GivenOptions given(ctx);
        const std::vector<std::string> requested = canonicalizeLocaleList(ctx, argc > 0 ? argv[0] : JS_UNDEFINED);
        Value options = coerceOptionsToObject(ctx, argc > 1 ? argv[1] : JS_UNDEFINED);
        getStringOption(ctx, options.get(), "localeMatcher", kMatchers);
        std::optional<std::string> numberingSystem = getStringOption(ctx, options.get(), "numberingSystem", {}, &given);
        if (numberingSystem && !isUnicodeType(*numberingSystem)) {
            throw RangeError{"Intl: the value of numberingSystem is out of range."};
        }
        const std::string locale = resolveLocale(ctx, requested, RelevantKeys::RelativeTimeFormat);
        const uint8_t style = uint8_t(optionIndex(getStringOption(ctx, options.get(), "style", kWidths, &given), kWidths, 0));
        const uint8_t numeric = uint8_t(optionIndex(getStringOption(ctx, options.get(), "numeric", kNumerics, &given), kNumerics, 0));
        return createIntlObject<RelativeTimeFormatObject>(ctx, proto.get(), id, locale, given.json(), style, numeric).release();
    });
}

/// ECMA-402 SingularRelativeTimeUnit's check: a RangeError for anything but its units, singular or plural.
void checkRelativeUnit(const String& unit) {
    static const char* const kUnits[] = {"second", "seconds", "minute", "minutes", "hour",    "hours",    "day",  "days",
                                         "week",   "weeks",   "month",  "months",  "quarter", "quarters", "year", "years"};
    for (const char* u : kUnits) {
        if (unit.equalsASCII(u)) {
            return;
        }
    }
    throw RangeError{"Intl.RelativeTimeFormat: invalid unit."};
}

JSValue relativeTimeFormat(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        const RelativeTimeFormatObject& rtf = intlReceiver<RelativeTimeFormatObject>(
            ctx, thisVal, classOf(ctx, IntlClass::RelativeTimeFormat), "Intl.RelativeTimeFormat.prototype.format");
        double value = 0;
        if (JS_ToFloat64(ctx, &value, argc > 0 ? argv[0] : JS_UNDEFINED) < 0) {
            throw Thrown{};
        }
        const String unit = String::fromJS(ctx, argc > 1 ? argv[1] : JS_UNDEFINED);
        if (!std::isfinite(value)) {
            throw RangeError{"Intl.RelativeTimeFormat: the value is not finite."};
        }
        checkRelativeUnit(unit);
        IntlRequest request(ctx, "relative");
        request.string("locale", rtf.locale).raw("opts", optsOf(rtf)).number("value", value).string("unit", unit);
        return answerString(ctx, request.send());
    });
}

JSValue relativeTimeResolvedOptions(JSContext* ctx, JSValueConst thisVal, int, JSValueConst*) {
    return glue(ctx, [&]() -> JSValue {
        const RelativeTimeFormatObject& rtf = intlReceiver<RelativeTimeFormatObject>(
            ctx, thisVal, classOf(ctx, IntlClass::RelativeTimeFormat), "Intl.RelativeTimeFormat.prototype.resolvedOptions");
        Value o = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
        defineString(ctx, o.get(), "locale", rtf.locale);
        defineString(ctx, o.get(), "style", optionAt(kWidths, rtf.style));
        defineString(ctx, o.get(), "numeric", optionAt(kNumerics, rtf.numeric));
        defineString(ctx, o.get(), "numberingSystem", rtf.numberingSystem);
        return o.release();
    });
}

const JSCFunctionListEntry kRelativeTimePrototype[] = {
    JS_CFUNC_DEF("format", 2, relativeTimeFormat),
    JS_CFUNC_DEF("resolvedOptions", 0, relativeTimeResolvedOptions),
    JS_PROP_STRING_DEF("[Symbol.toStringTag]", "Intl.RelativeTimeFormat", JS_PROP_CONFIGURABLE),
};

// ───────────── ListFormat

struct ListFormatObject : IntlObjectBase {
    ListFormatObject(std::string_view locale, JSText opts, uint8_t type, uint8_t style)
        : IntlObjectBase(locale, std::move(opts)), type(type), style(style) {}
    uint8_t type = 0;
    uint8_t style = 0;
};

/// ECMA-402 IteratorClose with a throw completion: the iterator's return is called, and what it throws or returns is
/// dropped (the pending error wins), unless the widget is stopping.
void closeIterator(JSContext* ctx, JSValueConst iterator) {
    auto drop = [&]() {
        if (Runtime::from(ctx).stopReason() != StopReason::None) {
            throw Thrown{};
        }
        JS_FreeValue(ctx, JS_GetException(ctx));
    };
    Value method = Value::adopt(ctx, JS_GetPropertyStr(ctx, iterator, "return"));
    if (JS_IsException(method.get())) {
        drop();
        return;
    }
    if (JS_IsFunction(ctx, method.get())) {
        Value result = Value::adopt(ctx, JS_Call(ctx, method.get(), iterator, 0, nullptr));
        if (JS_IsException(result.get())) {
            drop();
        }
    }
}

/// The strings of `list` through its iterator (the well-known @@iterator), as a JSON array into `json`: at most
/// kMaxListItems items and kMaxIntlString units in all. Throws TypeError and RangeError after closing the iterator.
void readStringList(JSContext* ctx, JSValueConst list, JSText& json) {
    const char* const what = "Intl.ListFormat.prototype.format";
    Value method = Value::adopt(ctx, checked(ctx, JS_GetProperty(ctx, list, Runtime::from(ctx).iteratorSymbol())));
    if (!JS_IsFunction(ctx, method.get())) {
        throw TypeError{std::string(what) + ": the list is not iterable."};
    }
    Value iterator = Value::adopt(ctx, checked(ctx, JS_Call(ctx, method.get(), list, 0, nullptr)));
    if (!JS_IsObject(iterator.get())) {
        throw TypeError{std::string(what) + ": the iterator is not an object."};
    }
    Value next = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, iterator.get(), "next")));
    size_t items = 0, units = 0;
    for (;;) {
        Value result = Value::adopt(ctx, checked(ctx, JS_Call(ctx, next.get(), iterator.get(), 0, nullptr)));
        if (!JS_IsObject(result.get())) {
            throw TypeError{std::string(what) + ": the iterator result is not an object."};
        }
        Value done = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, result.get(), "done")));
        if (JS_ToBool(ctx, done.get())) {
            return;
        }
        Value value = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, result.get(), "value")));
        if (!JS_IsString(value.get())) {
            closeIterator(ctx, iterator.get());
            throw TypeError{std::string(what) + ": an item is not a string."};
        }
        if (items == kMaxListItems) {
            closeIterator(ctx, iterator.get());
            throw RangeError{std::string(what) + ": the list has more than 10000 items."};
        }
        const String item = String::fromJS(ctx, value.get());
        if (units + item.length() > kMaxIntlString) {
            closeIterator(ctx, iterator.get());
            throw RangeError{std::string(what) + ": the list is too long."};
        }
        json += items ? "," : "";
        appendJSONString(json, item.utf8ForParse());
        units += item.length();
        items++;
    }
}

JSValue listConstruct(JSContext* ctx, JSValueConst newTarget, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        requireNew(newTarget, "ListFormat");
        const JSClassID id = classOf(ctx, IntlClass::ListFormat);
        Value proto = prototypeFromConstructor(ctx, newTarget, id);
        GivenOptions given(ctx);
        const std::vector<std::string> requested = canonicalizeLocaleList(ctx, argc > 0 ? argv[0] : JS_UNDEFINED);
        Value options = getOptionsObject(ctx, argc > 1 ? argv[1] : JS_UNDEFINED);
        getStringOption(ctx, options.get(), "localeMatcher", kMatchers);
        const std::string locale = resolveLocale(ctx, requested, RelevantKeys::None);
        const uint8_t type = uint8_t(optionIndex(getStringOption(ctx, options.get(), "type", kListTypes, &given), kListTypes, 0));
        const uint8_t style = uint8_t(optionIndex(getStringOption(ctx, options.get(), "style", kWidths, &given), kWidths, 0));
        return createIntlObject<ListFormatObject>(ctx, proto.get(), id, locale, given.json(), type, style).release();
    });
}

JSValue listFormat(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        const ListFormatObject& lf = intlReceiver<ListFormatObject>(ctx, thisVal, classOf(ctx, IntlClass::ListFormat),
                                                                     "Intl.ListFormat.prototype.format");
        // ECMA-402 StringListFromIterable, item by item: undefined is the empty list; a non-string item, or one past the
        // caps, closes the iterator and throws.
        JSValueConst list = argc > 0 ? argv[0] : JS_UNDEFINED;
        JSText items(lf.opts.get_allocator());
        items += "[";
        if (!JS_IsUndefined(list)) {
            readStringList(ctx, list, items);
        }
        items += "]";
        IntlRequest request(ctx, "list");
        request.string("locale", lf.locale).raw("opts", optsOf(lf)).raw("value", std::string_view(items.data(), items.size()));
        return answerString(ctx, request.send());
    });
}

JSValue listResolvedOptions(JSContext* ctx, JSValueConst thisVal, int, JSValueConst*) {
    return glue(ctx, [&]() -> JSValue {
        const ListFormatObject& lf = intlReceiver<ListFormatObject>(ctx, thisVal, classOf(ctx, IntlClass::ListFormat),
                                                                     "Intl.ListFormat.prototype.resolvedOptions");
        Value o = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
        defineString(ctx, o.get(), "locale", lf.locale);
        defineString(ctx, o.get(), "type", optionAt(kListTypes, lf.type));
        defineString(ctx, o.get(), "style", optionAt(kWidths, lf.style));
        return o.release();
    });
}

const JSCFunctionListEntry kListPrototype[] = {
    JS_CFUNC_DEF("format", 1, listFormat),
    JS_CFUNC_DEF("resolvedOptions", 0, listResolvedOptions),
    JS_PROP_STRING_DEF("[Symbol.toStringTag]", "Intl.ListFormat", JS_PROP_CONFIGURABLE),
};

// ───────────── Collator

struct CollatorRecord {
    char collation[16] = "default";
    uint8_t usage = 0;
    uint8_t sensitivity = 3;
    bool ignorePunctuation = false;
    bool numeric = false;
    uint8_t caseFirst = 2;  // kCaseFirsts: "false"
};

struct CollatorObject : IntlObjectBase {
    CollatorObject(std::string_view locale, JSText opts, const CollatorRecord& record)
        : IntlObjectBase(locale, std::move(opts)), record(record) {}
    CollatorRecord record;
};

/// ECMA-402 InitializeCollator, every option in its order: the object a constructor makes, or localeCompare's.
CollatorObject initializeCollator(JSContext* ctx, JSValueConst locales, JSValueConst optionsValue) {
    CollatorRecord r;
    GivenOptions given(ctx);
    const std::vector<std::string> requested = canonicalizeLocaleList(ctx, locales);
    Value options = coerceOptionsToObject(ctx, optionsValue);
    JSValueConst o = options.get();
    r.usage = uint8_t(optionIndex(getStringOption(ctx, o, "usage", kUsages, &given), kUsages, 0));
    getStringOption(ctx, o, "localeMatcher", kMatchers);
    std::optional<std::string> collation = getStringOption(ctx, o, "collation", {}, &given);
    if (collation && !isUnicodeType(*collation)) {
        throw RangeError{"Intl: the value of collation is out of range."};
    }
    r.numeric = getBooleanOption(ctx, o, "numeric", &given).value_or(false);
    r.caseFirst = uint8_t(optionIndex(getStringOption(ctx, o, "caseFirst", kCaseFirsts, &given), kCaseFirsts, 2));
    const std::string locale = resolveLocale(ctx, requested, RelevantKeys::Collator);
    r.sensitivity = uint8_t(optionIndex(getStringOption(ctx, o, "sensitivity", kSensitivities, &given), kSensitivities, 3));
    r.ignorePunctuation = getBooleanOption(ctx, o, "ignorePunctuation", &given).value_or(false);
    if (r.usage == 0 && collation && *collation != "standard" && *collation != "search" && collation->size() < sizeof(r.collation)) {
        std::copy(collation->begin(), collation->end(), r.collation);
        r.collation[collation->size()] = 0;
    }
    return CollatorObject(locale, given.json(), r);
}

/// ECMA-402 CompareStrings, after both operands are strings: the host's order, or the code units' when it gives none.
int compareStrings(JSContext* ctx, const CollatorObject& collator, const String& x, const String& y) {
    IntlRequest request(ctx, "compare");
    request.string("locale", collator.locale).raw("opts", optsOf(collator)).string("a", x).string("b", y);
    const std::string answer = request.send();
    char* end = nullptr;
    const long order = std::strtol(answer.c_str(), &end, 10);
    if (!answer.empty() && end && *end == 0) {
        return order < 0 ? -1 : order > 0 ? 1 : 0;
    }
    const Text16 a = utf16Of(ctx, x);
    const Text16 b = utf16Of(ctx, y);
    return a < b ? -1 : b < a ? 1 : 0;
}

JSValue collatorConstruct(JSContext* ctx, JSValueConst newTarget, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        const JSClassID id = classOf(ctx, IntlClass::Collator);
        Value proto = prototypeFromConstructor(ctx, newTarget, id);
        CollatorObject collator = initializeCollator(ctx, argc > 0 ? argv[0] : JS_UNDEFINED, argc > 1 ? argv[1] : JS_UNDEFINED);
        return createIntlObject<CollatorObject>(ctx, proto.get(), id, collator.locale, std::move(collator.opts), collator.record).release();
    });
}

JSValue boundCompare(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv, int, JSValueConst* data) {
    return glue(ctx, [&]() -> JSValue {
        const CollatorObject& collator = intlReceiver<CollatorObject>(ctx, data[0], classOf(ctx, IntlClass::Collator), "compare");
        const String x = String::fromJS(ctx, argc > 0 ? argv[0] : JS_UNDEFINED);
        const String y = String::fromJS(ctx, argc > 1 ? argv[1] : JS_UNDEFINED);
        return JS_NewInt32(ctx, compareStrings(ctx, collator, x, y));
    });
}

JSValue collatorGetCompare(JSContext* ctx, JSValueConst thisVal) {
    return glue(ctx, [&]() -> JSValue {
        CollatorObject& collator = intlReceiver<CollatorObject>(ctx, thisVal, classOf(ctx, IntlClass::Collator),
                                                                "Intl.Collator.prototype.compare");
        if (JS_IsUndefined(collator.bound)) {
            collator.bound = boundIntlFunction(ctx, boundCompare, 2, thisVal);
        }
        return JS_DupValue(ctx, collator.bound);
    });
}

JSValue collatorResolvedOptions(JSContext* ctx, JSValueConst thisVal, int, JSValueConst*) {
    return glue(ctx, [&]() -> JSValue {
        const CollatorObject& collator = intlReceiver<CollatorObject>(ctx, thisVal, classOf(ctx, IntlClass::Collator),
                                                                      "Intl.Collator.prototype.resolvedOptions");
        const CollatorRecord& r = collator.record;
        Value o = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
        defineString(ctx, o.get(), "locale", collator.locale);
        defineString(ctx, o.get(), "usage", optionAt(kUsages, r.usage));
        defineString(ctx, o.get(), "sensitivity", optionAt(kSensitivities, r.sensitivity));
        defineBool(ctx, o.get(), "ignorePunctuation", r.ignorePunctuation);
        defineString(ctx, o.get(), "collation", r.collation);
        defineBool(ctx, o.get(), "numeric", r.numeric);
        defineString(ctx, o.get(), "caseFirst", optionAt(kCaseFirsts, r.caseFirst));
        return o.release();
    });
}

const JSCFunctionListEntry kCollatorPrototype[] = {
    JS_CGETSET_DEF("compare", collatorGetCompare, nullptr),
    JS_CFUNC_DEF("resolvedOptions", 0, collatorResolvedOptions),
    JS_PROP_STRING_DEF("[Symbol.toStringTag]", "Intl.Collator", JS_PROP_CONFIGURABLE),
};

JSValue localeCompare(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        if (JS_IsUndefined(thisVal) || JS_IsNull(thisVal)) {
            throw TypeError{"String.prototype.localeCompare called on null or undefined."};
        }
        const String s = String::fromJS(ctx, thisVal);
        const String that = String::fromJS(ctx, argc > 0 ? argv[0] : JS_UNDEFINED);
        const CollatorObject collator = initializeCollator(ctx, argc > 1 ? argv[1] : JS_UNDEFINED, argc > 2 ? argv[2] : JS_UNDEFINED);
        return JS_NewInt32(ctx, compareStrings(ctx, collator, s, that));
    });
}

/// ECMA-402 TransformCase's available locales: the languages whose case mappings differ from the root's, as ICU's case
/// mapping knows them (Turkish and Azeri dotted and dotless i, Lithuanian dot above, Greek accents in upper case,
/// Armenian ech-yiwn).
bool hasOwnCaseRules(std::string_view language) {
    return language == "az" || language == "el" || language == "hy" || language == "lt" || language == "tr";
}

/// String.prototype.toLocaleUpperCase (magic 1) and toLocaleLowerCase (0), ECMA-402 TransformCase: the first requested
/// locale, else the host's; in a language with case rules of its own, ICU's mapping for that language; otherwise the
/// root's mapping, which is the engine's own toUpperCase or toLowerCase (data[0], kept at install).
JSValue transformCase(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv, int magic, JSValueConst* data) {
    const bool upper = magic != 0;
    return glue(ctx, [&]() -> JSValue {
        if (JS_IsUndefined(thisVal) || JS_IsNull(thisVal)) {
            throw TypeError{upper ? "String.prototype.toLocaleUpperCase called on null or undefined."
                                  : "String.prototype.toLocaleLowerCase called on null or undefined."};
        }
        const String s = String::fromJS(ctx, thisVal);
        const std::vector<std::string> requested = canonicalizeLocaleList(ctx, argc > 0 ? argv[0] : JS_UNDEFINED);
        const std::string tag = requested.empty() ? resolveLocale(ctx, {}, RelevantKeys::None) : requested.front();
        const std::string language = tag.substr(0, tag.find('-'));
        if (!hasOwnCaseRules(language)) {
            JSValue string = s.toJS(ctx);
            JSValue mapped = JS_Call(ctx, data[0], string, 0, nullptr);
            JS_FreeValue(ctx, string);
            return checked(ctx, mapped);
        }
        const uint32_t length = s.length();
        Text16 units{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
        const JSStringView view = s.view();
        if (view.utf16) {
            units.assign(view.utf16, view.utf16 + length);
        } else if (view.latin1) {
            units.assign(view.latin1, view.latin1 + length);
        }
        // Not icuText: a case map has no length limit of its own (the string's is the engine's), and a mapping can grow
        // (ß is SS, İ in lower case is i and a dot): a quarter more first, then exactly what ICU asks for.
        auto map = [&](char16_t* buffer, int32_t capacity, UErrorCode* status) {
            return upper ? u_strToUpper(buffer, capacity, units.data(), int32_t(units.size()), language.c_str(), status)
                         : u_strToLower(buffer, capacity, units.data(), int32_t(units.size()), language.c_str(), status);
        };
        Text16 out{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
        out.resize(size_t(length) + length / 4 + 16);
        UErrorCode status = U_ZERO_ERROR;
        int32_t mapped = map(out.data(), int32_t(out.size()), &status);
        if (status == U_BUFFER_OVERFLOW_ERROR && mapped > 0) {
            out.resize(size_t(mapped));
            status = U_ZERO_ERROR;
            mapped = map(out.data(), int32_t(out.size()), &status);
        }
        if (U_FAILURE(status) || mapped < 0) {
            throw RangeError{std::string("Invalid string length: ") + u_errorName(status)};
        }
        out.resize(size_t(mapped));
        return String::fromUTF16(ctx, out.data(), out.size()).toJS(ctx);
    });
}

} // namespace

void defineTextFormats(JSContext* ctx, JSValueConst intl) {
    JSClassID id = registerIntlClass(ctx, IntlClass::PluralRules, "PluralRules", finalizeIntlObject<PluralRulesObject>,
                                     markIntlObject<PluralRulesObject>);
    defineIntlConstructor(ctx, intl, id, "PluralRules", pluralRulesConstruct, 0, kPluralRulesPrototype, int(std::size(kPluralRulesPrototype)));
    id = registerIntlClass(ctx, IntlClass::RelativeTimeFormat, "RelativeTimeFormat", finalizeIntlObject<RelativeTimeFormatObject>,
                           markIntlObject<RelativeTimeFormatObject>);
    defineIntlConstructor(ctx, intl, id, "RelativeTimeFormat", relativeTimeConstruct, 0, kRelativeTimePrototype,
                          int(std::size(kRelativeTimePrototype)));
    id = registerIntlClass(ctx, IntlClass::ListFormat, "ListFormat", finalizeIntlObject<ListFormatObject>, markIntlObject<ListFormatObject>);
    defineIntlConstructor(ctx, intl, id, "ListFormat", listConstruct, 0, kListPrototype, int(std::size(kListPrototype)));
    id = registerIntlClass(ctx, IntlClass::Collator, "Collator", finalizeIntlObject<CollatorObject>, markIntlObject<CollatorObject>);
    defineIntlConstructor(ctx, intl, id, "Collator", collatorConstruct, 0, kCollatorPrototype, int(std::size(kCollatorPrototype)));
}

void installStringOverrides(JSContext* ctx) {
    Value global = Value::adopt(ctx, JS_GetGlobalObject(ctx));
    Value constructor = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, global.get(), "String")));
    Value proto = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, constructor.get(), "prototype")));
    JSValue function = checked(ctx, JS_NewCFunction(ctx, localeCompare, "localeCompare", 1));
    check(ctx, JS_DefinePropertyValueStr(ctx, proto.get(), "localeCompare", function, JS_PROP_WRITABLE | JS_PROP_CONFIGURABLE));
    // ECMA-402 TransformCase (widget-sandbox v0.1.1's Intl fixture: "i" in Turkish is "İ"); the engine's own maps are
    // the root's, kept here before any script can replace them.
    for (const auto& [name, plain, upper] : {std::tuple{"toLocaleUpperCase", "toUpperCase", 1}, std::tuple{"toLocaleLowerCase", "toLowerCase", 0}}) {
        Value root = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, proto.get(), plain)));
        JSValueConst rootData[] = {root.get()};
        JSValue mapped = checked(ctx, JS_NewCFunctionData2(ctx, transformCase, name, 0, upper, 1, rootData));
        check(ctx, JS_DefinePropertyValueStr(ctx, proto.get(), name, mapped, JS_PROP_WRITABLE | JS_PROP_CONFIGURABLE));
    }
}

} // namespace wr::intl
