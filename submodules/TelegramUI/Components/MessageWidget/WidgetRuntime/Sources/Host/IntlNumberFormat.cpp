// Intl.NumberFormat (V5b plan, Task 2; ECMA-402 §15) and Number/BigInt.prototype.toLocaleString: the options read in
// ECMA-402's order into a NumberFormatRecord and the ones given kept, then the host's `number`, `numberParts` and
// `numberOptions` requests (Sources/Host/Intl.h).
#include <algorithm>
#include <cctype>
#include <climits>
#include <cmath>
#include <iterator>
#include <memory>
#include <string_view>

#include "Sources/Host/Intl.h"
#include "Sources/Runtime/Runtime.h"

namespace wr::intl {

namespace {

const std::initializer_list<const char*> kStyles = {"decimal", "percent", "currency", "unit"};
const std::initializer_list<const char*> kCurrencyDisplays = {"code", "symbol", "narrowSymbol", "name"};
const std::initializer_list<const char*> kCurrencySigns = {"standard", "accounting"};
const std::initializer_list<const char*> kUnitDisplays = {"short", "narrow", "long"};
const std::initializer_list<const char*> kNotations = {"standard", "scientific", "engineering", "compact"};
const std::initializer_list<const char*> kCompactDisplays = {"short", "long"};
const std::initializer_list<const char*> kGroupings = {"min2", "auto", "always"};
const std::initializer_list<const char*> kSignDisplays = {"auto", "never", "always", "exceptZero", "negative"};
const std::initializer_list<const char*> kRoundingModes = {"ceil",     "floor",      "expand",    "trunc",   "halfCeil",
                                                           "halfFloor", "halfExpand", "halfTrunc", "halfEven"};
const std::initializer_list<const char*> kRoundingPriorities = {"auto", "morePrecision", "lessPrecision"};
const std::initializer_list<const char*> kTrailingZeroDisplays = {"auto", "stripIfInteger"};
const int kRoundingIncrements[] = {1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 2500, 5000};

enum Style : uint8_t { Decimal, Percent, Currency, Unit };
enum Grouping : int8_t { GroupingOff = -1, Min2 = 0, Auto = 1, Always = 2 };

/// ECMA-402 Table 2's sanctioned simple units.
const char* const kSanctionedUnits[] = {
    "acre",       "bit",        "byte",       "celsius",     "centimeter",  "day",        "degree",
    "fahrenheit", "fluid-ounce", "foot",      "gallon",      "gigabit",     "gigabyte",   "gram",
    "hectare",    "hour",       "inch",       "kilobit",     "kilobyte",    "kilogram",   "kilometer",
    "liter",      "megabit",    "megabyte",   "meter",       "microsecond", "mile",       "mile-scandinavian",
    "milliliter", "millimeter", "millisecond", "minute",     "month",       "nanosecond", "ounce",
    "percent",    "petabyte",   "pound",      "second",      "stone",       "terabit",    "terabyte",
    "week",       "yard",       "year",
};

/// Intl.NumberFormat's options as ECMA-402 resolves them without locale data: resolvedOptions' answer where the host's
/// has none. Fixed-size.
struct NumberFormatRecord {
    char numberingSystem[16] = "latn";
    uint8_t style = Decimal;
    char currency[4] = {};
    uint8_t currencyDisplay = 1;
    uint8_t currencySign = 0;
    char unit[64] = {};
    uint8_t unitDisplay = 0;
    Notation notation = Notation::Standard;
    uint8_t compactDisplay = 0;
    int8_t useGrouping = Auto;
    uint8_t signDisplay = 0;
    DigitOptions digits;
};

struct NumberFormatObject : IntlObjectBase {
    NumberFormatObject(std::string_view locale, JSText opts, const NumberFormatRecord& record)
        : IntlObjectBase(locale, std::move(opts)), record(record) {}
    NumberFormatRecord record;
};

bool isSanctioned(std::string_view unit) {
    for (const char* u : kSanctionedUnits) {
        if (unit == u) {
            return true;
        }
    }
    return false;
}

/// ECMA-402 IsWellFormedUnitIdentifier.
bool isWellFormedUnit(std::string_view unit) {
    if (isSanctioned(unit)) {
        return true;
    }
    const size_t per = unit.find("-per-");
    return per != std::string_view::npos && isSanctioned(unit.substr(0, per)) && isSanctioned(unit.substr(per + 5));
}

/// ECMA-402 IsWellFormedCurrencyCode.
bool isWellFormedCurrency(std::string_view code) {
    return code.size() == 3 && std::all_of(code.begin(), code.end(), [](char c) {
               return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
           });
}

/// ECMA-402 DefaultNumberOption over a value already read: nullopt for undefined; a defined one added to `given`.
std::optional<int> defaultNumberOption(JSContext* ctx, const Value& value, int min, int max, const char* name,
                                       GivenOptions* given) {
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

Value getRaw(JSContext* ctx, JSValueConst options, const char* name) {
    return Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, options, name)));
}

/// What InitializeNumberFormat makes: the locale the requests name, the options given, and the record.
struct NumberFormatSetup {
    std::string locale;
    JSText opts;
    NumberFormatRecord record;
};

/// ECMA-402 InitializeNumberFormat, every option in its order.
NumberFormatSetup initializeNumberFormat(JSContext* ctx, JSValueConst locales, JSValueConst options) {
    NumberFormatRecord r;
    GivenOptions given(ctx);
    const std::vector<std::string> requested = canonicalizeLocaleList(ctx, locales);
    Value object = coerceOptionsToObject(ctx, options);
    JSValueConst o = object.get();
    getStringOption(ctx, o, "localeMatcher", {"lookup", "best fit"});
    std::optional<std::string> numberingSystem = getStringOption(ctx, o, "numberingSystem", {}, &given);
    if (numberingSystem && !isUnicodeType(*numberingSystem)) {
        throw RangeError{"Intl: the value of numberingSystem is out of range."};
    }
    const std::string locale = resolveLocale(ctx, requested, RelevantKeys::NumberFormat);
    // SetNumberFormatUnitOptions.
    r.style = uint8_t(optionIndex(getStringOption(ctx, o, "style", kStyles, &given), kStyles, Decimal));
    std::optional<std::string> currency = getStringOption(ctx, o, "currency", {}, &given);
    if (!currency) {
        if (r.style == Currency) {
            throw TypeError{"Intl.NumberFormat: the currency style needs a currency."};
        }
    } else if (!isWellFormedCurrency(*currency)) {
        throw RangeError{"Intl.NumberFormat: the currency code is not well formed."};
    }
    const uint8_t currencyDisplay =
        uint8_t(optionIndex(getStringOption(ctx, o, "currencyDisplay", kCurrencyDisplays, &given), kCurrencyDisplays, 1));
    const uint8_t currencySign = uint8_t(optionIndex(getStringOption(ctx, o, "currencySign", kCurrencySigns, &given), kCurrencySigns, 0));
    std::optional<std::string> unit = getStringOption(ctx, o, "unit", {}, &given);
    if (!unit) {
        if (r.style == Unit) {
            throw TypeError{"Intl.NumberFormat: the unit style needs a unit."};
        }
    } else if (!isWellFormedUnit(*unit)) {
        throw RangeError{"Intl.NumberFormat: the unit is not well formed."};
    }
    const uint8_t unitDisplay = uint8_t(optionIndex(getStringOption(ctx, o, "unitDisplay", kUnitDisplays, &given), kUnitDisplays, 0));
    if (r.style == Currency) {
        std::string upper = *currency;
        for (char& c : upper) {
            c = char(std::toupper(uint8_t(c)));
        }
        std::copy(upper.begin(), upper.end(), r.currency);
        r.currencyDisplay = currencyDisplay;
        r.currencySign = currencySign;
    }
    if (r.style == Unit && unit->size() < sizeof(r.unit)) {
        std::copy(unit->begin(), unit->end(), r.unit);
        r.unitDisplay = unitDisplay;
    }
    // A currency's own digits are the host's (resolvedOptions takes them from its answer); here ISO 4217's usual two,
    // which only ECMA-402's checks of the digit options read.
    int mnfdDefault = 0, mxfdDefault = 3;
    if (r.style == Currency) {
        mnfdDefault = mxfdDefault = 2;
    } else if (r.style == Percent) {
        mxfdDefault = 0;
    }
    r.notation = Notation(optionIndex(getStringOption(ctx, o, "notation", kNotations, &given), kNotations, 0));
    readDigitOptions(ctx, o, mnfdDefault, mxfdDefault, r.notation, r.digits, &given);
    r.compactDisplay = uint8_t(optionIndex(getStringOption(ctx, o, "compactDisplay", kCompactDisplays, &given), kCompactDisplays, 0));
    // GetBooleanOrStringNumberFormatOption(options, "useGrouping", « "min2", "auto", "always", "true", "false" », …).
    const int8_t defaultGrouping = r.notation == Notation::Compact ? Min2 : Auto;
    Value grouping = getRaw(ctx, o, "useGrouping");
    if (JS_IsUndefined(grouping.get())) {
        r.useGrouping = defaultGrouping;
    } else if (JS_IsBool(grouping.get()) && JS_ToBool(ctx, grouping.get())) {
        r.useGrouping = Always;
        given.addBool("useGrouping", true);
    } else if (!JS_ToBool(ctx, grouping.get())) {
        r.useGrouping = GroupingOff;
        given.addBool("useGrouping", false);
    } else {
        const String text = String::fromJS(ctx, grouping.get());
        if (text.equalsASCII("true") || text.equalsASCII("false")) {
            r.useGrouping = defaultGrouping;
        } else if (text.equalsASCII("min2")) {
            r.useGrouping = Min2;
        } else if (text.equalsASCII("auto")) {
            r.useGrouping = Auto;
        } else if (text.equalsASCII("always")) {
            r.useGrouping = Always;
        } else {
            throw RangeError{"Intl: the value of useGrouping is out of range."};
        }
        given.addString("useGrouping", text.utf8());
    }
    r.signDisplay = uint8_t(optionIndex(getStringOption(ctx, o, "signDisplay", kSignDisplays, &given), kSignDisplays, 0));
    return NumberFormatSetup{locale, given.json(), r};
}

/// ECMA-402 ToIntlMathematicalValue, for a Number or a BigInt (anything else goes through ToNumber: Ruling).
struct Numeric {
    bool isBigInt = false;
    double value = 0;
    std::string digits;
};

Numeric toIntlMathematicalValue(JSContext* ctx, JSValueConst x) {
    Numeric n;
    if (JS_IsBigInt(x)) {
        size_t length = 0;
        const char* text = JS_ToCStringLen(ctx, &length, x);
        if (!text) {
            throw Thrown{};
        }
        struct Owned {
            JSContext* ctx;
            const char* text;
            ~Owned() { JS_FreeCString(ctx, text); }
        } owned{ctx, text};
        if (length > kMaxIntlString) {
            throw RangeError{"Intl.NumberFormat: the BigInt is too long."};
        }
        n.isBigInt = true;
        n.digits.assign(text, length);
        return n;
    }
    if (JS_ToFloat64(ctx, &n.value, x) < 0) {
        throw Thrown{};
    }
    return n;
}

/// The host's answer to `kind` for `nf` and `n`: a BigInt as its digits, a JSON number the glue reads as the shim's
/// Number(value).
std::string ask(JSContext* ctx, const char* kind, const NumberFormatObject& nf, const Numeric* n) {
    IntlRequest request(ctx, kind);
    request.string("locale", nf.locale).raw("opts", std::string_view(nf.opts.data(), nf.opts.size()));
    if (n) {
        if (n->isBigInt) {
            request.raw("value", n->digits);
        } else {
            request.number("value", n->value);
        }
    }
    return request.send();
}

/// NaN and the infinities, which a request cannot carry (JSON has no such number; the shim's null formats as 0):
/// ECMA-402's symbols, the sign where signDisplay puts it.
struct NonFinite {
    const char* sign;
    const char* type;
    const char* text;
};

std::optional<NonFinite> nonFinite(const NumberFormatRecord& r, const Numeric& n) {
    if (n.isBigInt || std::isfinite(n.value)) {
        return std::nullopt;
    }
    if (n.value != n.value) {
        return NonFinite{"", "nan", "NaN"};
    }
    const bool negative = n.value < 0;
    // kSignDisplays: auto, never, always, exceptZero, negative.
    const char* sign = r.signDisplay == 1 ? "" : negative ? "-" : (r.signDisplay == 2 || r.signDisplay == 3) ? "+" : "";
    return NonFinite{sign, "infinity", "∞"};
}

JSValue formatNumeric(JSContext* ctx, const NumberFormatObject& nf, const Numeric& n) {
    if (std::optional<NonFinite> special = nonFinite(nf.record, n)) {
        return answerString(ctx, std::string(special->sign) + special->text);
    }
    return answerString(ctx, ask(ctx, "number", nf, &n));
}

JSValue formatNumericToParts(JSContext* ctx, const NumberFormatObject& nf, const Numeric& n) {
    if (std::optional<NonFinite> special = nonFinite(nf.record, n)) {
        Value parts = Value::adopt(ctx, checked(ctx, JS_NewArray(ctx)));
        uint32_t count = 0;
        auto add = [&](const char* type, const char* value) {
            Value part = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
            defineString(ctx, part.get(), "type", type);
            defineString(ctx, part.get(), "value", value);
            check(ctx, JS_DefinePropertyValueUint32(ctx, parts.get(), count++, part.release(), JS_PROP_C_W_E));
        };
        if (*special->sign) {
            add(*special->sign == '-' ? "minusSign" : "plusSign", special->sign);
        }
        add(special->type, special->text);
        return parts.release();
    }
    return answerJSON(ctx, ask(ctx, "numberParts", nf, &n), true).release();
}

JSClassID numberFormatClass(JSContext* ctx) {
    return intlState(ctx).classIds[size_t(IntlClass::NumberFormat)];
}

JSValue boundFormat(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv, int, JSValueConst* data) {
    return glue(ctx, [&]() -> JSValue {
        NumberFormatObject& nf = intlReceiver<NumberFormatObject>(ctx, data[0], numberFormatClass(ctx), "format");
        const Numeric n = toIntlMathematicalValue(ctx, argc > 0 ? argv[0] : JS_UNDEFINED);
        return formatNumeric(ctx, nf, n);
    });
}

JSValue getFormat(JSContext* ctx, JSValueConst thisVal) {
    return glue(ctx, [&]() -> JSValue {
        NumberFormatObject& nf = intlReceiver<NumberFormatObject>(ctx, thisVal, numberFormatClass(ctx),
                                                                  "Intl.NumberFormat.prototype.format");
        if (JS_IsUndefined(nf.bound)) {
            nf.bound = boundIntlFunction(ctx, boundFormat, 1, thisVal);
        }
        return JS_DupValue(ctx, nf.bound);
    });
}

JSValue formatToParts(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        NumberFormatObject& nf = intlReceiver<NumberFormatObject>(ctx, thisVal, numberFormatClass(ctx),
                                                                  "Intl.NumberFormat.prototype.formatToParts");
        const Numeric n = toIntlMathematicalValue(ctx, argc > 0 ? argv[0] : JS_UNDEFINED);
        return formatNumericToParts(ctx, nf, n);
    });
}

JSValue resolvedOptions(JSContext* ctx, JSValueConst thisVal, int, JSValueConst*) {
    return glue(ctx, [&]() -> JSValue {
        const NumberFormatObject& nf = intlReceiver<NumberFormatObject>(ctx, thisVal, numberFormatClass(ctx),
                                                                        "Intl.NumberFormat.prototype.resolvedOptions");
        const NumberFormatRecord& r = nf.record;
        Value o = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
        defineString(ctx, o.get(), "locale", nf.locale);
        defineString(ctx, o.get(), "numberingSystem", r.numberingSystem);
        defineString(ctx, o.get(), "style", optionAt(kStyles, r.style));
        if (r.style == Currency) {
            defineString(ctx, o.get(), "currency", r.currency);
            defineString(ctx, o.get(), "currencyDisplay", optionAt(kCurrencyDisplays, r.currencyDisplay));
            defineString(ctx, o.get(), "currencySign", optionAt(kCurrencySigns, r.currencySign));
        }
        if (r.style == Unit) {
            defineString(ctx, o.get(), "unit", r.unit);
            defineString(ctx, o.get(), "unitDisplay", optionAt(kUnitDisplays, r.unitDisplay));
        }
        defineDigitCounts(ctx, o.get(), r.digits);
        if (r.useGrouping == GroupingOff) {
            defineBool(ctx, o.get(), "useGrouping", false);
        } else {
            defineString(ctx, o.get(), "useGrouping", optionAt(kGroupings, size_t(r.useGrouping)));
        }
        defineString(ctx, o.get(), "notation", optionAt(kNotations, size_t(r.notation)));
        if (r.notation == Notation::Compact) {
            defineString(ctx, o.get(), "compactDisplay", optionAt(kCompactDisplays, r.compactDisplay));
        }
        defineString(ctx, o.get(), "signDisplay", optionAt(kSignDisplays, r.signDisplay));
        defineRoundingOptions(ctx, o.get(), r.digits);
        // What needs locale data (the locale the glue formats in, its numbering system, a currency's digits) is the
        // host's; the rest is ours.
        Value answer = answerJSON(ctx, ask(ctx, "numberOptions", nf, nullptr), false);
        return mergedOptions(ctx, answer.get(), o.get(),
                             {"locale", "numberingSystem", "style", "currency", "currencyDisplay", "currencySign", "unit",
                              "unitDisplay", "minimumIntegerDigits", "minimumFractionDigits", "maximumFractionDigits",
                              "minimumSignificantDigits", "maximumSignificantDigits", "useGrouping", "notation",
                              "compactDisplay", "signDisplay", "roundingIncrement", "roundingMode", "roundingPriority",
                              "trailingZeroDisplay"});
    });
}

JSValue construct(JSContext* ctx, JSValueConst newTarget, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        const JSClassID id = numberFormatClass(ctx);
        Value proto = prototypeFromConstructor(ctx, newTarget, id);
        NumberFormatSetup setup = initializeNumberFormat(ctx, argc > 0 ? argv[0] : JS_UNDEFINED, argc > 1 ? argv[1] : JS_UNDEFINED);
        return createIntlObject<NumberFormatObject>(ctx, proto.get(), id, setup.locale, std::move(setup.opts), setup.record).release();
    });
}

const JSCFunctionListEntry kPrototype[] = {
    JS_CGETSET_DEF("format", getFormat, nullptr),
    JS_CFUNC_DEF("formatToParts", 1, formatToParts),
    JS_CFUNC_DEF("resolvedOptions", 0, resolvedOptions),
    JS_PROP_STRING_DEF("[Symbol.toStringTag]", "Intl.NumberFormat", JS_PROP_CONFIGURABLE),
};

JSValue toLocaleString(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv, int magic) {
    return glue(ctx, [&]() -> JSValue {
        // thisNumberValue / thisBigIntValue, through the engine's own valueOf.
        const Runtime::Intrinsic valueOf = magic ? Runtime::Intrinsic::BigIntValueOf : Runtime::Intrinsic::NumberValueOf;
        Value x = Value::adopt(ctx, checked(ctx, JS_Call(ctx, Runtime::from(ctx).intrinsic(valueOf), thisVal, 0, nullptr)));
        return formatNumberToLocaleString(ctx, x.get(), argc > 0 ? argv[0] : JS_UNDEFINED, argc > 1 ? argv[1] : JS_UNDEFINED);
    });
}

} // namespace

void readDigitOptions(JSContext* ctx, JSValueConst o, int mnfdDefault, int mxfdDefault, Notation notation, DigitOptions& out,
                      GivenOptions* given) {
    out.minimumIntegerDigits = getNumberOption(ctx, o, "minimumIntegerDigits", 1, 21, given).value_or(1);
    Value mnfd = getRaw(ctx, o, "minimumFractionDigits");
    Value mxfd = getRaw(ctx, o, "maximumFractionDigits");
    Value mnsd = getRaw(ctx, o, "minimumSignificantDigits");
    Value mxsd = getRaw(ctx, o, "maximumSignificantDigits");
    const int increment = getNumberOption(ctx, o, "roundingIncrement", 1, 5000, given).value_or(1);
    if (std::find(std::begin(kRoundingIncrements), std::end(kRoundingIncrements), increment) == std::end(kRoundingIncrements)) {
        throw RangeError{"Intl: the value of roundingIncrement is out of range."};
    }
    out.roundingMode = uint8_t(optionIndex(getStringOption(ctx, o, "roundingMode", kRoundingModes, given), kRoundingModes, 6));
    const int priority = optionIndex(getStringOption(ctx, o, "roundingPriority", kRoundingPriorities, given), kRoundingPriorities, 0);
    out.stripIfInteger =
        optionIndex(getStringOption(ctx, o, "trailingZeroDisplay", kTrailingZeroDisplays, given), kTrailingZeroDisplays, 0) == 1;
    if (increment != 1) {
        mxfdDefault = mnfdDefault;
    }
    out.roundingIncrement = increment;
    const bool hasSd = !JS_IsUndefined(mnsd.get()) || !JS_IsUndefined(mxsd.get());
    const bool hasFd = !JS_IsUndefined(mnfd.get()) || !JS_IsUndefined(mxfd.get());
    bool needSd = true, needFd = true;
    if (priority == 0) {
        needSd = hasSd;
        if (needSd || (!hasFd && notation == Notation::Compact)) {
            needFd = false;
        }
    }
    if (needSd) {
        if (hasSd) {
            out.minimumSignificantDigits = defaultNumberOption(ctx, mnsd, 1, 21, "minimumSignificantDigits", given).value_or(1);
            out.maximumSignificantDigits =
                defaultNumberOption(ctx, mxsd, out.minimumSignificantDigits, 21, "maximumSignificantDigits", given).value_or(21);
        } else {
            out.minimumSignificantDigits = 1;
            out.maximumSignificantDigits = 21;
        }
    }
    if (needFd) {
        if (hasFd) {
            std::optional<int> min = defaultNumberOption(ctx, mnfd, 0, 100, "minimumFractionDigits", given);
            std::optional<int> max = defaultNumberOption(ctx, mxfd, 0, 100, "maximumFractionDigits", given);
            if (!min) {
                min = std::min(mnfdDefault, *max);
            } else if (!max) {
                max = std::max(mxfdDefault, *min);
            } else if (*min > *max) {
                throw RangeError{"Intl: minimumFractionDigits is more than maximumFractionDigits."};
            }
            out.minimumFractionDigits = *min;
            out.maximumFractionDigits = *max;
        } else {
            out.minimumFractionDigits = mnfdDefault;
            out.maximumFractionDigits = mxfdDefault;
        }
    }
    if (!needSd && !needFd) {
        out.minimumFractionDigits = 0;
        out.maximumFractionDigits = 0;
        out.minimumSignificantDigits = 1;
        out.maximumSignificantDigits = 2;
        out.roundingType = RoundingType::MorePrecision;
        out.computedRoundingPriority = 1;
    } else if (priority == 0) {
        out.roundingType = hasSd ? RoundingType::SignificantDigits : RoundingType::FractionDigits;
        out.computedRoundingPriority = 0;
    } else {
        out.roundingType = priority == 1 ? RoundingType::MorePrecision : RoundingType::LessPrecision;
        out.computedRoundingPriority = uint8_t(priority);
    }
    if (increment != 1) {
        if (out.roundingType != RoundingType::FractionDigits) {
            throw TypeError{"Intl: roundingIncrement needs fraction digits."};
        }
        if (out.maximumFractionDigits != out.minimumFractionDigits) {
            throw RangeError{"Intl: roundingIncrement needs equal minimum and maximum fraction digits."};
        }
    }
}

void defineDigitCounts(JSContext* ctx, JSValueConst o, const DigitOptions& d) {
    defineInt(ctx, o, "minimumIntegerDigits", d.minimumIntegerDigits);
    if (d.roundingType != RoundingType::SignificantDigits) {
        defineInt(ctx, o, "minimumFractionDigits", d.minimumFractionDigits);
        defineInt(ctx, o, "maximumFractionDigits", d.maximumFractionDigits);
    }
    if (d.roundingType != RoundingType::FractionDigits) {
        defineInt(ctx, o, "minimumSignificantDigits", d.minimumSignificantDigits);
        defineInt(ctx, o, "maximumSignificantDigits", d.maximumSignificantDigits);
    }
}

void defineRoundingOptions(JSContext* ctx, JSValueConst o, const DigitOptions& d) {
    defineInt(ctx, o, "roundingIncrement", d.roundingIncrement);
    defineString(ctx, o, "roundingMode", optionAt(kRoundingModes, d.roundingMode));
    defineString(ctx, o, "roundingPriority", optionAt(kRoundingPriorities, d.computedRoundingPriority));
    defineString(ctx, o, "trailingZeroDisplay", optionAt(kTrailingZeroDisplays, d.stripIfInteger ? 1 : 0));
}

JSValue formatNumberToLocaleString(JSContext* ctx, JSValueConst x, JSValueConst locales, JSValueConst options) {
    NumberFormatSetup setup = initializeNumberFormat(ctx, locales, options);
    const Numeric n = toIntlMathematicalValue(ctx, x);
    const NumberFormatObject nf(setup.locale, std::move(setup.opts), setup.record);
    return formatNumeric(ctx, nf, n);
}

void defineNumberFormat(JSContext* ctx, JSValueConst intl) {
    const JSClassID id = registerIntlClass(ctx, IntlClass::NumberFormat, "NumberFormat",
                                           finalizeIntlObject<NumberFormatObject>, markIntlObject<NumberFormatObject>);
    defineIntlConstructor(ctx, intl, id, "NumberFormat", construct, 0, kPrototype, int(std::size(kPrototype)));
}

void installNumberOverrides(JSContext* ctx) {
    Value global = Value::adopt(ctx, JS_GetGlobalObject(ctx));
    for (int bigint = 0; bigint < 2; bigint++) {
        Value constructor = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, global.get(), bigint ? "BigInt" : "Number")));
        Value proto = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, constructor.get(), "prototype")));
        JSValue function = checked(ctx, JS_NewCFunctionMagic(ctx, toLocaleString, "toLocaleString", 0, JS_CFUNC_generic_magic, bigint));
        check(ctx, JS_DefinePropertyValueStr(ctx, proto.get(), "toLocaleString", function, JS_PROP_WRITABLE | JS_PROP_CONFIGURABLE));
    }
}

} // namespace wr::intl
