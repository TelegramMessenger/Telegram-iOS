// Intl.PluralRules, RelativeTimeFormat, ListFormat and Collator, and String.prototype.localeCompare (V5b plan, Task 4;
// ECMA-402 §16, §17, §13, §10). Each reads its options in ECMA-402's order into a fixed-size record; the ICU plural
// rules, relative time formatter, list formatter or collator for that record comes from the runtime's IntlCache when
// it is used, after every argument is converted.
#include <array>
#include <cctype>
#include <cmath>
#include <memory>
#include <string_view>
#include <tuple>

#include "Sources/Host/Intl.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Work.h"

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

const char* at(std::initializer_list<const char*> list, size_t index) {
    return *(list.begin() + std::ptrdiff_t(index));
}

void defineString(JSContext* ctx, JSValueConst object, const char* name, std::string_view value) {
    check(ctx, JS_DefinePropertyValueStr(ctx, object, name, JS_NewStringLen(ctx, value.data(), value.size()), JS_PROP_C_W_E));
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

void withKeyword(char (&icuLocale)[ULOC_FULLNAME_CAPACITY + 1], const char* key, const std::string& value) {
    char buffer[ULOC_FULLNAME_CAPACITY + 1] = {};
    copyInto(buffer, icuLocale);
    UErrorCode status = U_ZERO_ERROR;
    uloc_setKeywordValue(key, value.c_str(), buffer, ULOC_FULLNAME_CAPACITY, &status);
    if (U_SUCCESS(status) && status != U_STRING_NOT_TERMINATED_WARNING) {
        copyInto(icuLocale, buffer);
    }
}

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

/// A fixed-size locale record every text format has.
struct Locales {
    char locale[kMaxLocaleTag + 1] = {};
    char icuLocale[ULOC_FULLNAME_CAPACITY + 1] = {};
    void resolve(JSContext* ctx, const std::vector<std::string>& requested) {
        const std::string tag = resolveLocale(ctx, requested);
        copyInto(locale, tag);
        copyInto(icuLocale, toICULocale(tag));
    }
};

// ───────────── PluralRules

struct PluralRulesObject : IntlObjectBase {
    Locales locales;
    uint8_t type = 0;
    DigitOptions digits;
};

UPluralRules* pluralRulesFor(JSContext* ctx, const PluralRulesObject& pr) {
    UPluralRules* rules = intlState(ctx).cache.get<UPluralRules>(
        ctx, std::string("pr\x1f") + pr.locales.icuLocale + "\x1f" + char('0' + pr.type),
        [&]() -> UPluralRules* {
            UErrorCode status = U_ZERO_ERROR;
            UPluralRules* made = uplrules_openForType(pr.locales.icuLocale, UPluralType(pr.type), &status);
            if (U_FAILURE(status)) {
                if (made) {
                    uplrules_close(made);
                }
                return nullptr;
            }
            return made;
        },
        uplrules_close);
    if (!rules) {
        throw RangeError{"Intl.PluralRules: ICU refused the locale."};
    }
    return rules;
}

UNumberFormatter* pluralNumberFormatter(JSContext* ctx, const PluralRulesObject& pr) {
    std::u16string skeleton = u"numbering-system/latn " + digitsSkeleton(pr.digits);
    const std::string key = std::string("prnf\x1f") + pr.locales.icuLocale + "\x1f" + std::string(skeleton.begin(), skeleton.end());
    UNumberFormatter* f = intlState(ctx).cache.get<UNumberFormatter>(
        ctx, key,
        [&]() -> UNumberFormatter* {
            UErrorCode status = U_ZERO_ERROR;
            UNumberFormatter* made = unumf_openForSkeletonAndLocale(skeleton.data(), int32_t(skeleton.size()), pr.locales.icuLocale, &status);
            if (U_FAILURE(status)) {
                if (made) {
                    unumf_close(made);
                }
                return nullptr;
            }
            return made;
        },
        unumf_close);
    if (!f) {
        throw RangeError{"Intl.PluralRules: ICU refused the digit options."};
    }
    return f;
}

JSValue pluralRulesConstruct(JSContext* ctx, JSValueConst newTarget, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        requireNew(newTarget, "PluralRules");
        const JSClassID id = classOf(ctx, IntlClass::PluralRules);
        Value proto = prototypeFromConstructor(ctx, newTarget, id);
        PluralRulesObject pr;
        const std::vector<std::string> requested = canonicalizeLocaleList(ctx, argc > 0 ? argv[0] : JS_UNDEFINED);
        Value options = coerceOptionsToObject(ctx, argc > 1 ? argv[1] : JS_UNDEFINED);
        getStringOption(ctx, options.get(), "localeMatcher", kMatchers);
        pr.type = uint8_t(optionIndex(getStringOption(ctx, options.get(), "type", kPluralTypes), kPluralTypes, 0));
        readDigitOptions(ctx, options.get(), 0, 3, Notation::Standard, pr.digits);
        pr.locales.resolve(ctx, requested);
        Value object = createIntlObject<PluralRulesObject>(ctx, proto.get(), id, pr);
        return object.release();
    });
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
        UNumberFormatter* f = pluralNumberFormatter(ctx, pr);
        UPluralRules* rules = pluralRulesFor(ctx, pr);
        UErrorCode status = U_ZERO_ERROR;
        std::unique_ptr<UFormattedNumber, void (*)(UFormattedNumber*)> result(unumf_openResult(&status), unumf_closeResult);
        if (U_FAILURE(status) || !result) {
            throw RangeError{"Intl.PluralRules: ICU failed."};
        }
        unumf_formatDouble(f, n, result.get(), &status);
        if (U_FAILURE(status)) {
            throw RangeError{"Intl.PluralRules: ICU failed."};
        }
        return icuString(ctx, [&](char16_t* buffer, int32_t capacity, UErrorCode* st) {
            return uplrules_selectFormatted(rules, result.get(), buffer, capacity, st);
        });
    });
}

JSValue pluralRulesResolvedOptions(JSContext* ctx, JSValueConst thisVal, int, JSValueConst*) {
    return glue(ctx, [&]() -> JSValue {
        const PluralRulesObject& pr = intlReceiver<PluralRulesObject>(ctx, thisVal, classOf(ctx, IntlClass::PluralRules),
                                                                       "Intl.PluralRules.prototype.resolvedOptions");
        UPluralRules* rules = pluralRulesFor(ctx, pr);
        std::array<bool, 6> present{};
        {
            UErrorCode status = U_ZERO_ERROR;
            std::unique_ptr<UEnumeration, void (*)(UEnumeration*)> keywords(uplrules_getKeywords(rules, &status), uenum_close);
            int32_t length = 0;
            while (U_SUCCESS(status) && keywords) {
                const char* keyword = uenum_next(keywords.get(), &length, &status);
                if (!keyword) {
                    break;
                }
                for (size_t i = 0; i < present.size(); i++) {
                    present[i] = present[i] || std::string_view(keyword, size_t(length)) == kPluralCategories[i];
                }
            }
        }
        Value o = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
        defineString(ctx, o.get(), "locale", pr.locales.locale);
        defineString(ctx, o.get(), "type", at(kPluralTypes, pr.type));
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
    Locales locales;
    char numberingSystem[16] = {};
    uint8_t style = 0;
    uint8_t numeric = 0;
};

JSValue relativeTimeConstruct(JSContext* ctx, JSValueConst newTarget, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        requireNew(newTarget, "RelativeTimeFormat");
        const JSClassID id = classOf(ctx, IntlClass::RelativeTimeFormat);
        Value proto = prototypeFromConstructor(ctx, newTarget, id);
        RelativeTimeFormatObject rtf;
        const std::vector<std::string> requested = canonicalizeLocaleList(ctx, argc > 0 ? argv[0] : JS_UNDEFINED);
        Value options = coerceOptionsToObject(ctx, argc > 1 ? argv[1] : JS_UNDEFINED);
        getStringOption(ctx, options.get(), "localeMatcher", kMatchers);
        std::optional<std::string> numberingSystem = getStringOption(ctx, options.get(), "numberingSystem", {});
        if (numberingSystem && !isUnicodeType(*numberingSystem)) {
            throw RangeError{"Intl: the value of numberingSystem is out of range."};
        }
        rtf.locales.resolve(ctx, requested);
        if (numberingSystem && isSupportedNumberingSystem(*numberingSystem)) {
            withKeyword(rtf.locales.icuLocale, "numbers", *numberingSystem);
        }
        rtf.style = uint8_t(optionIndex(getStringOption(ctx, options.get(), "style", kWidths), kWidths, 0));
        rtf.numeric = uint8_t(optionIndex(getStringOption(ctx, options.get(), "numeric", kNumerics), kNumerics, 0));
        UErrorCode status = U_ZERO_ERROR;
        std::unique_ptr<UNumberingSystem, void (*)(UNumberingSystem*)> numbering(unumsys_open(rtf.locales.icuLocale, &status), unumsys_close);
        copyInto(rtf.numberingSystem, U_SUCCESS(status) && numbering ? std::string(unumsys_getName(numbering.get())) : std::string("latn"));
        return createIntlObject<RelativeTimeFormatObject>(ctx, proto.get(), id, rtf).release();
    });
}

/// ECMA-402 SingularRelativeTimeUnit then the ICU unit; a RangeError for anything else.
URelativeDateTimeUnit relativeUnit(const String& unit) {
    static const struct {
        const char* singular;
        const char* plural;
        URelativeDateTimeUnit icu;
    } kUnits[] = {
        {"second", "seconds", UDAT_REL_UNIT_SECOND}, {"minute", "minutes", UDAT_REL_UNIT_MINUTE},
        {"hour", "hours", UDAT_REL_UNIT_HOUR},       {"day", "days", UDAT_REL_UNIT_DAY},
        {"week", "weeks", UDAT_REL_UNIT_WEEK},       {"month", "months", UDAT_REL_UNIT_MONTH},
        {"quarter", "quarters", UDAT_REL_UNIT_QUARTER}, {"year", "years", UDAT_REL_UNIT_YEAR},
    };
    for (const auto& u : kUnits) {
        if (unit.equalsASCII(u.singular) || unit.equalsASCII(u.plural)) {
            return u.icu;
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
        const String unitString = String::fromJS(ctx, argc > 1 ? argv[1] : JS_UNDEFINED);
        if (!std::isfinite(value)) {
            throw RangeError{"Intl.RelativeTimeFormat: the value is not finite."};
        }
        const URelativeDateTimeUnit unit = relativeUnit(unitString);
        URelativeDateTimeFormatter* f = intlState(ctx).cache.get<URelativeDateTimeFormatter>(
            ctx, std::string("rtf\x1f") + rtf.locales.icuLocale + "\x1f" + char('0' + rtf.style),
            [&]() -> URelativeDateTimeFormatter* {
                UErrorCode status = U_ZERO_ERROR;
                URelativeDateTimeFormatter* made = ureldatefmt_open(rtf.locales.icuLocale, nullptr,
                                                                    UDateRelativeDateTimeFormatterStyle(rtf.style),
                                                                    UDISPCTX_CAPITALIZATION_NONE, &status);
                if (U_FAILURE(status)) {
                    if (made) {
                        ureldatefmt_close(made);
                    }
                    return nullptr;
                }
                return made;
            },
            ureldatefmt_close);
        if (!f) {
            throw RangeError{"Intl.RelativeTimeFormat: ICU refused the locale."};
        }
        return icuString(ctx, [&](char16_t* buffer, int32_t capacity, UErrorCode* status) {
            return rtf.numeric == 1 ? ureldatefmt_format(f, value, unit, buffer, capacity, status)
                                    : ureldatefmt_formatNumeric(f, value, unit, buffer, capacity, status);
        });
    });
}

JSValue relativeTimeResolvedOptions(JSContext* ctx, JSValueConst thisVal, int, JSValueConst*) {
    return glue(ctx, [&]() -> JSValue {
        const RelativeTimeFormatObject& rtf = intlReceiver<RelativeTimeFormatObject>(
            ctx, thisVal, classOf(ctx, IntlClass::RelativeTimeFormat), "Intl.RelativeTimeFormat.prototype.resolvedOptions");
        Value o = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
        defineString(ctx, o.get(), "locale", rtf.locales.locale);
        defineString(ctx, o.get(), "style", at(kWidths, rtf.style));
        defineString(ctx, o.get(), "numeric", at(kNumerics, rtf.numeric));
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
    Locales locales;
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

/// The strings of `list` through its iterator (the well-known @@iterator), each item charged as it is read, into
/// `units` and `lengths`: at most kMaxListItems items and kMaxIntlString units in all. Throws TypeError and RangeError
/// after closing the iterator.
void readStringList(JSContext* ctx, JSValueConst list, Text16& units, Vector<int32_t>& lengths) {
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
    for (;;) {
        charge(ctx, work::kNodeVisit);
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
        if (lengths.size() == kMaxListItems) {
            closeIterator(ctx, iterator.get());
            throw RangeError{std::string(what) + ": the list has more than 10000 items."};
        }
        const String item = String::fromJS(ctx, value.get());
        if (units.size() + item.length() > kMaxIntlString) {
            closeIterator(ctx, iterator.get());
            throw RangeError{std::string(what) + ": the list is too long."};
        }
        const Text16 text = utf16Of(ctx, item);
        units.insert(units.end(), text.begin(), text.end());
        lengths.push_back(int32_t(text.size()));
    }
}

JSValue listConstruct(JSContext* ctx, JSValueConst newTarget, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        requireNew(newTarget, "ListFormat");
        const JSClassID id = classOf(ctx, IntlClass::ListFormat);
        Value proto = prototypeFromConstructor(ctx, newTarget, id);
        ListFormatObject lf;
        const std::vector<std::string> requested = canonicalizeLocaleList(ctx, argc > 0 ? argv[0] : JS_UNDEFINED);
        Value options = getOptionsObject(ctx, argc > 1 ? argv[1] : JS_UNDEFINED);
        getStringOption(ctx, options.get(), "localeMatcher", kMatchers);
        lf.locales.resolve(ctx, requested);
        lf.type = uint8_t(optionIndex(getStringOption(ctx, options.get(), "type", kListTypes), kListTypes, 0));
        lf.style = uint8_t(optionIndex(getStringOption(ctx, options.get(), "style", kWidths), kWidths, 0));
        return createIntlObject<ListFormatObject>(ctx, proto.get(), id, lf).release();
    });
}

JSValue listFormat(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        const ListFormatObject& lf = intlReceiver<ListFormatObject>(ctx, thisVal, classOf(ctx, IntlClass::ListFormat),
                                                                     "Intl.ListFormat.prototype.format");
        // ECMA-402 StringListFromIterable, item by item: undefined is the empty list; a non-string item, or one past the
        // caps, closes the iterator and throws.
        JSValueConst list = argc > 0 ? argv[0] : JS_UNDEFINED;
        Text16 units{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
        Vector<int32_t> lengths{JSAllocator<int32_t>(JS_GetRuntime(ctx))};
        if (!JS_IsUndefined(list)) {
            readStringList(ctx, list, units, lengths);
        }
        Vector<const char16_t*> starts{JSAllocator<const char16_t*>(JS_GetRuntime(ctx))};
        size_t offset = 0;
        for (int32_t length : lengths) {
            starts.push_back(units.data() + offset);
            offset += size_t(length);
        }
        UListFormatter* f = intlState(ctx).cache.get<UListFormatter>(
            ctx, std::string("lf\x1f") + lf.locales.icuLocale + "\x1f" + char('0' + lf.type) + char('0' + lf.style),
            [&]() -> UListFormatter* {
                UErrorCode status = U_ZERO_ERROR;
                UListFormatter* made = ulistfmt_openForType(lf.locales.icuLocale, UListFormatterType(lf.type),
                                                            UListFormatterWidth(lf.style), &status);
                if (U_FAILURE(status)) {
                    if (made) {
                        ulistfmt_close(made);
                    }
                    return nullptr;
                }
                return made;
            },
            ulistfmt_close);
        if (!f) {
            throw RangeError{"Intl.ListFormat: ICU refused the locale."};
        }
        return icuString(ctx, [&](char16_t* buffer, int32_t capacity, UErrorCode* status) {
            return ulistfmt_format(f, starts.data(), lengths.data(), int32_t(lengths.size()), buffer, capacity, status);
        });
    });
}

JSValue listResolvedOptions(JSContext* ctx, JSValueConst thisVal, int, JSValueConst*) {
    return glue(ctx, [&]() -> JSValue {
        const ListFormatObject& lf = intlReceiver<ListFormatObject>(ctx, thisVal, classOf(ctx, IntlClass::ListFormat),
                                                                     "Intl.ListFormat.prototype.resolvedOptions");
        Value o = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
        defineString(ctx, o.get(), "locale", lf.locales.locale);
        defineString(ctx, o.get(), "type", at(kListTypes, lf.type));
        defineString(ctx, o.get(), "style", at(kWidths, lf.style));
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
    Locales locales;
    char collation[16] = "default";
    uint8_t usage = 0;
    uint8_t sensitivity = 3;
    // -1 when the option was not given: the locale's own value stands (Danish sorts upper case first, Thai ignores
    // punctuation) and resolvedOptions reads it back from ICU.
    int8_t ignorePunctuation = -1;
    int8_t numeric = -1;
    int8_t caseFirst = -1;
};

struct CollatorObject : IntlObjectBase {
    explicit CollatorObject(const CollatorRecord& record) : record(record) {}
    CollatorRecord record;
};

CollatorRecord initializeCollator(JSContext* ctx, JSValueConst locales, JSValueConst optionsValue) {
    CollatorRecord r;
    const std::vector<std::string> requested = canonicalizeLocaleList(ctx, locales);
    Value options = coerceOptionsToObject(ctx, optionsValue);
    JSValueConst o = options.get();
    r.usage = uint8_t(optionIndex(getStringOption(ctx, o, "usage", kUsages), kUsages, 0));
    getStringOption(ctx, o, "localeMatcher", kMatchers);
    std::optional<std::string> collation = getStringOption(ctx, o, "collation", {});
    if (collation && !isUnicodeType(*collation)) {
        throw RangeError{"Intl: the value of collation is out of range."};
    }
    if (std::optional<bool> numeric = getBooleanOption(ctx, o, "numeric")) {
        r.numeric = int8_t(*numeric);
    }
    r.caseFirst = int8_t(optionIndex(getStringOption(ctx, o, "caseFirst", kCaseFirsts), kCaseFirsts, -1));
    r.locales.resolve(ctx, requested);
    r.sensitivity = uint8_t(optionIndex(getStringOption(ctx, o, "sensitivity", kSensitivities), kSensitivities, 3));
    if (std::optional<bool> ignorePunctuation = getBooleanOption(ctx, o, "ignorePunctuation")) {
        r.ignorePunctuation = int8_t(*ignorePunctuation);
    }
    if (r.usage == 1) {
        withKeyword(r.locales.icuLocale, "collation", "search");
    } else if (collation && *collation != "standard" && *collation != "search" && collation->size() < sizeof(r.collation)) {
        withKeyword(r.locales.icuLocale, "collation", *collation);
        copyInto(r.collation, *collation);
    }
    return r;
}

UCollator* collatorFor(JSContext* ctx, const CollatorRecord& r) {
    const std::string key = std::string("col\x1f") + r.locales.icuLocale + "\x1f" + char('0' + r.sensitivity) +
                            char('1' + r.caseFirst) + char('1' + r.numeric) + char('1' + r.ignorePunctuation);
    UCollator* collator = intlState(ctx).cache.get<UCollator>(
        ctx, key,
        [&]() -> UCollator* {
            UErrorCode status = U_ZERO_ERROR;
            UCollator* made = ucol_open(r.locales.icuLocale, &status);
            if (U_FAILURE(status)) {
                if (made) {
                    ucol_close(made);
                }
                return nullptr;
            }
            // Only what the options gave: the rest keeps the locale's tailoring.
            if (r.numeric >= 0) {
                ucol_setAttribute(made, UCOL_NUMERIC_COLLATION, r.numeric ? UCOL_ON : UCOL_OFF, &status);
            }
            if (r.caseFirst >= 0) {
                const UColAttributeValue firsts[] = {UCOL_UPPER_FIRST, UCOL_LOWER_FIRST, UCOL_OFF};
                ucol_setAttribute(made, UCOL_CASE_FIRST, firsts[r.caseFirst], &status);
            }
            const UColAttributeValue strengths[] = {UCOL_PRIMARY, UCOL_SECONDARY, UCOL_PRIMARY, UCOL_TERTIARY};
            ucol_setAttribute(made, UCOL_STRENGTH, strengths[r.sensitivity], &status);
            ucol_setAttribute(made, UCOL_CASE_LEVEL, r.sensitivity == 2 ? UCOL_ON : UCOL_OFF, &status);
            if (r.ignorePunctuation >= 0) {
                ucol_setAttribute(made, UCOL_ALTERNATE_HANDLING, r.ignorePunctuation ? UCOL_SHIFTED : UCOL_NON_IGNORABLE, &status);
            }
            if (U_FAILURE(status)) {
                ucol_close(made);
                return nullptr;
            }
            return made;
        },
        ucol_close);
    if (!collator) {
        throw RangeError{"Intl.Collator: ICU refused the locale."};
    }
    return collator;
}

/// ECMA-402 CompareStrings, after both operands are strings.
int compareStrings(JSContext* ctx, const CollatorRecord& r, const String& x, const String& y) {
    const Text16 a = utf16Of(ctx, x);
    const Text16 b = utf16Of(ctx, y);
    UCollator* collator = collatorFor(ctx, r);
    return int(ucol_strcoll(collator, a.data(), int32_t(a.size()), b.data(), int32_t(b.size())));
}

JSValue collatorConstruct(JSContext* ctx, JSValueConst newTarget, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        const JSClassID id = classOf(ctx, IntlClass::Collator);
        Value proto = prototypeFromConstructor(ctx, newTarget, id);
        const CollatorRecord record = initializeCollator(ctx, argc > 0 ? argv[0] : JS_UNDEFINED, argc > 1 ? argv[1] : JS_UNDEFINED);
        return createIntlObject<CollatorObject>(ctx, proto.get(), id, record).release();
    });
}

JSValue boundCompare(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv, int, JSValueConst* data) {
    return glue(ctx, [&]() -> JSValue {
        const CollatorObject& collator = intlReceiver<CollatorObject>(ctx, data[0], classOf(ctx, IntlClass::Collator), "compare");
        const String x = String::fromJS(ctx, argc > 0 ? argv[0] : JS_UNDEFINED);
        const String y = String::fromJS(ctx, argc > 1 ? argv[1] : JS_UNDEFINED);
        return JS_NewInt32(ctx, compareStrings(ctx, collator.record, x, y));
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
        const CollatorRecord& r = intlReceiver<CollatorObject>(ctx, thisVal, classOf(ctx, IntlClass::Collator),
                                                               "Intl.Collator.prototype.resolvedOptions")
                                      .record;
        Value o = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
        defineString(ctx, o.get(), "locale", r.locales.locale);
        defineString(ctx, o.get(), "usage", at(kUsages, r.usage));
        defineString(ctx, o.get(), "sensitivity", at(kSensitivities, r.sensitivity));
        // What the collator uses: the option when given, else the locale's own attribute.
        UCollator* collator = collatorFor(ctx, r);
        UErrorCode status = U_ZERO_ERROR;
        const bool ignorePunctuation = r.ignorePunctuation >= 0 ? r.ignorePunctuation != 0
                                                                : ucol_getAttribute(collator, UCOL_ALTERNATE_HANDLING, &status) == UCOL_SHIFTED;
        const bool numeric = r.numeric >= 0 ? r.numeric != 0 : ucol_getAttribute(collator, UCOL_NUMERIC_COLLATION, &status) == UCOL_ON;
        size_t caseFirst = 2;
        if (r.caseFirst >= 0) {
            caseFirst = size_t(r.caseFirst);
        } else {
            const UColAttributeValue first = ucol_getAttribute(collator, UCOL_CASE_FIRST, &status);
            caseFirst = first == UCOL_UPPER_FIRST ? 0 : first == UCOL_LOWER_FIRST ? 1 : 2;
        }
        defineBool(ctx, o.get(), "ignorePunctuation", ignorePunctuation);
        defineString(ctx, o.get(), "collation", r.collation);
        defineBool(ctx, o.get(), "numeric", numeric);
        defineString(ctx, o.get(), "caseFirst", at(kCaseFirsts, caseFirst));
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
        const CollatorRecord record = initializeCollator(ctx, argc > 1 ? argv[1] : JS_UNDEFINED, argc > 2 ? argv[2] : JS_UNDEFINED);
        return JS_NewInt32(ctx, compareStrings(ctx, record, s, that));
    });
}

/// ECMA-402 TransformCase's available locales: the languages whose case mappings differ from the root's, as ICU's case
/// mapping knows them (Turkish and Azeri dotted and dotless i, Lithuanian dot above, Greek accents in upper case,
/// Armenian ech-yiwn).
bool hasOwnCaseRules(std::string_view language) {
    return language == "az" || language == "el" || language == "hy" || language == "lt" || language == "tr";
}

/// String.prototype.toLocaleUpperCase (magic 1) and toLocaleLowerCase (0), ECMA-402 TransformCase: the first requested
/// locale, else the host's; in a language with case rules of its own, ICU's mapping for that language, charged
/// work::kCaseMapEightUnits per eight units on top of the copy's scan; otherwise the root's mapping, which is the
/// engine's own toUpperCase or toLowerCase (data[0], kept at install; QuickJS charges it).
JSValue transformCase(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv, int magic, JSValueConst* data) {
    const bool upper = magic != 0;
    return glue(ctx, [&]() -> JSValue {
        if (JS_IsUndefined(thisVal) || JS_IsNull(thisVal)) {
            throw TypeError{upper ? "String.prototype.toLocaleUpperCase called on null or undefined."
                                  : "String.prototype.toLocaleLowerCase called on null or undefined."};
        }
        const String s = String::fromJS(ctx, thisVal);
        const std::vector<std::string> requested = canonicalizeLocaleList(ctx, argc > 0 ? argv[0] : JS_UNDEFINED);
        const std::string tag = requested.empty() ? resolveLocale(ctx, {}) : requested.front();
        const std::string language = tag.substr(0, tag.find('-'));
        if (!hasOwnCaseRules(language)) {
            JSValue string = s.toJS(ctx);
            JSValue mapped = JS_Call(ctx, data[0], string, 0, nullptr);
            JS_FreeValue(ctx, string);
            return checked(ctx, mapped);
        }
        const uint32_t length = s.length();
        chargeScan(ctx, length);
        if (length >= 8) {
            charge(ctx, length / 8 * work::kCaseMapEightUnits);
        }
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
