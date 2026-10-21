// Intl.NumberFormat (V5b plan, Task 2; ECMA-402 §15) and Number/BigInt.prototype.toLocaleString: the options read in
// ECMA-402's order into a NumberFormatRecord, an ICU number skeleton made from it, and an ICU formatter for that
// skeleton taken from the runtime's IntlCache at format time.
#include <algorithm>
#include <cctype>
#include <climits>
#include <cmath>
#include <iterator>
#include <memory>
#include <string_view>

#include "Sources/Host/Intl.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Work.h"

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
const char* const kICURoundingModes[] = {"ceiling",    "floor",   "up",        "down",     "half-ceiling",
                                         "half-floor", "half-up", "half-down", "half-even"};
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

/// Intl.NumberFormat's resolved options: the payload's record, fixed-size.
struct NumberFormatRecord {
    char locale[kMaxLocaleTag + 1] = {};
    char icuLocale[ULOC_FULLNAME_CAPACITY + 1] = {};
    char numberingSystem[16] = {};
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
    explicit NumberFormatObject(const NumberFormatRecord& record) : record(record) {}
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

/// UTS 35's numbering-system type: (3*8alphanum) *("-" (3*8alphanum)).
bool isNumberingSystemType(std::string_view type) {
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

/// ECMA-402 DefaultNumberOption over a value already read: nullopt for undefined.
std::optional<int> defaultNumberOption(JSContext* ctx, const Value& value, int min, int max, const char* name) {
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

Value getRaw(JSContext* ctx, JSValueConst options, const char* name) {
    return Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, options, name)));
}

std::string defaultNumberingSystem(const char* icuLocale) {
    UErrorCode status = U_ZERO_ERROR;
    std::unique_ptr<UNumberingSystem, void (*)(UNumberingSystem*)> numbering(unumsys_open(icuLocale, &status), unumsys_close);
    if (U_FAILURE(status) || !numbering) {
        return "latn";
    }
    return unumsys_getName(numbering.get());
}

int currencyDigits(const char* currency) {
    char16_t code[4] = {char16_t(currency[0]), char16_t(currency[1]), char16_t(currency[2]), 0};
    UErrorCode status = U_ZERO_ERROR;
    const int32_t digits = ucurr_getDefaultFractionDigits(code, &status);
    return U_SUCCESS(status) && digits >= 0 ? int(digits) : 2;
}

/// ECMA-402 InitializeNumberFormat, every option in its order.
NumberFormatRecord initializeNumberFormat(JSContext* ctx, JSValueConst locales, JSValueConst options) {
    NumberFormatRecord r;
    const std::vector<std::string> requested = canonicalizeLocaleList(ctx, locales);
    Value object = coerceOptionsToObject(ctx, options);
    JSValueConst o = object.get();
    getStringOption(ctx, o, "localeMatcher", {"lookup", "best fit"});
    std::optional<std::string> numberingSystem = getStringOption(ctx, o, "numberingSystem", {});
    if (numberingSystem && !isNumberingSystemType(*numberingSystem)) {
        throw RangeError{"Intl: the value of numberingSystem is out of range."};
    }
    const std::string locale = resolveLocale(ctx, requested);
    copyInto(r.locale, locale);
    copyInto(r.icuLocale, toICULocale(locale));
    copyInto(r.numberingSystem, numberingSystem && isSupportedNumberingSystem(*numberingSystem)
                                    ? *numberingSystem
                                    : defaultNumberingSystem(r.icuLocale));
    // SetNumberFormatUnitOptions.
    r.style = uint8_t(optionIndex(getStringOption(ctx, o, "style", kStyles), kStyles, Decimal));
    std::optional<std::string> currency = getStringOption(ctx, o, "currency", {});
    if (!currency) {
        if (r.style == Currency) {
            throw TypeError{"Intl.NumberFormat: the currency style needs a currency."};
        }
    } else if (!isWellFormedCurrency(*currency)) {
        throw RangeError{"Intl.NumberFormat: the currency code is not well formed."};
    }
    const uint8_t currencyDisplay = uint8_t(optionIndex(getStringOption(ctx, o, "currencyDisplay", kCurrencyDisplays), kCurrencyDisplays, 1));
    const uint8_t currencySign = uint8_t(optionIndex(getStringOption(ctx, o, "currencySign", kCurrencySigns), kCurrencySigns, 0));
    std::optional<std::string> unit = getStringOption(ctx, o, "unit", {});
    if (!unit) {
        if (r.style == Unit) {
            throw TypeError{"Intl.NumberFormat: the unit style needs a unit."};
        }
    } else if (!isWellFormedUnit(*unit)) {
        throw RangeError{"Intl.NumberFormat: the unit is not well formed."};
    }
    const uint8_t unitDisplay = uint8_t(optionIndex(getStringOption(ctx, o, "unitDisplay", kUnitDisplays), kUnitDisplays, 0));
    if (r.style == Currency) {
        std::string upper = *currency;
        for (char& c : upper) {
            c = char(std::toupper(uint8_t(c)));
        }
        copyInto(r.currency, upper);
        r.currencyDisplay = currencyDisplay;
        r.currencySign = currencySign;
    }
    if (r.style == Unit) {
        copyInto(r.unit, *unit);
        r.unitDisplay = unitDisplay;
    }
    int mnfdDefault = 0, mxfdDefault = 3;
    if (r.style == Currency) {
        mnfdDefault = mxfdDefault = currencyDigits(r.currency);
    } else if (r.style == Percent) {
        mxfdDefault = 0;
    }
    r.notation = Notation(optionIndex(getStringOption(ctx, o, "notation", kNotations), kNotations, 0));
    readDigitOptions(ctx, o, mnfdDefault, mxfdDefault, r.notation, r.digits);
    r.compactDisplay = uint8_t(optionIndex(getStringOption(ctx, o, "compactDisplay", kCompactDisplays), kCompactDisplays, 0));
    // GetBooleanOrStringNumberFormatOption(options, "useGrouping", « "min2", "auto", "always", "true", "false" », …).
    const int8_t defaultGrouping = r.notation == Notation::Compact ? Min2 : Auto;
    Value grouping = getRaw(ctx, o, "useGrouping");
    if (JS_IsUndefined(grouping.get())) {
        r.useGrouping = defaultGrouping;
    } else if (JS_IsBool(grouping.get()) && JS_ToBool(ctx, grouping.get())) {
        r.useGrouping = Always;
    } else if (!JS_ToBool(ctx, grouping.get())) {
        r.useGrouping = GroupingOff;
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
    }
    r.signDisplay = uint8_t(optionIndex(getStringOption(ctx, o, "signDisplay", kSignDisplays), kSignDisplays, 0));
    return r;
}

std::u16string toU16(std::string_view ascii) {
    return std::u16string(ascii.begin(), ascii.end());
}

std::string fractionStem(int min, int max) {
    if (max == 0) {
        return "precision-integer";
    }
    return "." + std::string(size_t(min), '0') + std::string(size_t(max - min), '#');
}

std::string significantStem(int min, int max) {
    return std::string(size_t(min), '@') + std::string(size_t(max - min), '#');
}

/// `increment` / 10^digits with exactly `digits` fraction digits.
std::string incrementStem(int increment, int digits) {
    std::string s = std::to_string(increment);
    if (digits == 0) {
        return s;
    }
    if (s.size() <= size_t(digits)) {
        s.insert(0, size_t(digits) + 1 - s.size(), '0');
    }
    s.insert(s.size() - size_t(digits), ".");
    return s;
}

std::u16string skeleton(const NumberFormatRecord& r) {
    std::string s = std::string("numbering-system/") + r.numberingSystem;
    if (r.style == Percent) {
        s += " percent scale/100";
    } else if (r.style == Currency) {
        s += std::string(" currency/") + r.currency;
        const char* const widths[] = {" unit-width-iso-code", " unit-width-short", " unit-width-narrow", " unit-width-full-name"};
        s += widths[r.currencyDisplay];
    } else if (r.style == Unit) {
        s += std::string(" unit/") + r.unit;
        const char* const widths[] = {" unit-width-short", " unit-width-narrow", " unit-width-full-name"};
        s += widths[r.unitDisplay];
    }
    switch (r.notation) {
    case Notation::Scientific:
        s += " scientific";
        break;
    case Notation::Engineering:
        s += " engineering";
        break;
    case Notation::Compact:
        s += r.compactDisplay ? " compact-long" : " compact-short";
        break;
    case Notation::Standard:
        break;
    }
    const DigitOptions& d = r.digits;
    // Compact notation with no digit options rounds as ICU's compact notation does by default (ECMA-402's
    // morePrecision of 0 fraction and 2 significant digits).
    const bool compactDefault = r.notation == Notation::Compact && d.roundingType == RoundingType::MorePrecision &&
                                d.minimumFractionDigits == 0 && d.maximumFractionDigits == 0 &&
                                d.minimumSignificantDigits == 1 && d.maximumSignificantDigits == 2;
    if (compactDefault) {
        if (d.minimumIntegerDigits > 1) {
            s += " integer-width/*" + std::string(size_t(d.minimumIntegerDigits), '0');
        }
        s += std::string(" rounding-mode-") + kICURoundingModes[d.roundingMode];
    } else {
        const std::u16string digits = digitsSkeleton(d);
        s += " " + std::string(digits.begin(), digits.end());
    }
    switch (r.useGrouping) {
    case GroupingOff:
        s += " group-off";
        break;
    case Min2:
        s += " group-min2";
        break;
    case Always:
        s += " group-on-aligned";
        break;
    default:
        break;
    }
    const bool accounting = r.style == Currency && r.currencySign == 1;
    const char* const standardSigns[] = {"", " sign-never", " sign-always", " sign-except-zero", " sign-negative"};
    const char* const accountingSigns[] = {" sign-accounting", " sign-never", " sign-accounting-always",
                                           " sign-accounting-except-zero", " sign-accounting-negative"};
    s += accounting ? accountingSigns[r.signDisplay] : standardSigns[r.signDisplay];
    return toU16(s);
}

void closeFormatter(UNumberFormatter* f) {
    unumf_close(f);
}

/// The ICU formatter for `r`, from the cache. Throws RangeError when ICU refuses the skeleton.
UNumberFormatter* formatterFor(JSContext* ctx, const NumberFormatRecord& r) {
    const std::u16string sk = skeleton(r);
    const std::string key = std::string("nf\x1f") + r.icuLocale + "\x1f" + std::string(sk.begin(), sk.end());
    UNumberFormatter* f = intlState(ctx).cache.get<UNumberFormatter>(
        ctx, key,
        [&]() -> UNumberFormatter* {
            UErrorCode status = U_ZERO_ERROR;
            UNumberFormatter* made = unumf_openForSkeletonAndLocale(sk.data(), int32_t(sk.size()), r.icuLocale, &status);
            if (U_FAILURE(status)) {
                if (made) {
                    unumf_close(made);
                }
                return nullptr;
            }
            return made;
        },
        closeFormatter);
    if (!f) {
        throw RangeError{"Intl.NumberFormat: ICU refused the format."};
    }
    return f;
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
        chargeScan(ctx, length);
        n.isBigInt = true;
        n.digits.assign(text, length);
        return n;
    }
    if (JS_ToFloat64(ctx, &n.value, x) < 0) {
        throw Thrown{};
    }
    return n;
}

using Result = std::unique_ptr<UFormattedNumber, void (*)(UFormattedNumber*)>;

/// Formats `n` with `f` into a new result. Throws RangeError when ICU fails.
Result formatted(UNumberFormatter* f, const Numeric& n) {
    UErrorCode status = U_ZERO_ERROR;
    Result result(unumf_openResult(&status), unumf_closeResult);
    if (U_FAILURE(status) || !result) {
        throw RangeError{"Intl.NumberFormat: ICU failed."};
    }
    if (n.isBigInt) {
        unumf_formatDecimal(f, n.digits.data(), int32_t(n.digits.size()), result.get(), &status);
    } else {
        unumf_formatDouble(f, n.value, result.get(), &status);
    }
    if (U_FAILURE(status)) {
        throw RangeError{std::string("Intl.NumberFormat: ICU failed: ") + u_errorName(status)};
    }
    return result;
}

Text16 resultText(JSContext* ctx, const Result& result) {
    return icuText(ctx, [&](char16_t* buffer, int32_t capacity, UErrorCode* status) {
        return unumf_resultToString(result.get(), buffer, capacity, status);
    });
}

/// The ECMA-402 part type of ICU number field `field` covering `text`.
const char* partType(int field, std::u16string_view text, const void* context) {
    const Numeric& n = *static_cast<const Numeric*>(context);
    switch (field) {
    case UNUM_INTEGER_FIELD:
        if (!n.isBigInt && n.value != n.value) {
            return "nan";
        }
        if (!n.isBigInt && (n.value == HUGE_VAL || n.value == -HUGE_VAL)) {
            return "infinity";
        }
        return "integer";
    case UNUM_FRACTION_FIELD:
        return "fraction";
    case UNUM_DECIMAL_SEPARATOR_FIELD:
        return "decimal";
    case UNUM_EXPONENT_SYMBOL_FIELD:
        return "exponentSeparator";
    case UNUM_EXPONENT_SIGN_FIELD:
        return "exponentMinusSign";
    case UNUM_EXPONENT_FIELD:
        return "exponentInteger";
    case UNUM_GROUPING_SEPARATOR_FIELD:
        return "group";
    case UNUM_CURRENCY_FIELD:
        return "currency";
    case UNUM_PERCENT_FIELD:
        return "percentSign";
    case UNUM_SIGN_FIELD:
        return text.find(u'+') != std::u16string_view::npos ? "plusSign" : "minusSign";
    case UNUM_MEASURE_UNIT_FIELD:
        return "unit";
    case UNUM_COMPACT_FIELD:
        return "compact";
    case UNUM_APPROXIMATELY_SIGN_FIELD:
        return "approximatelySign";
    default:
        if (!n.isBigInt && n.value != n.value) {
            return "nan";
        }
        return "literal";
    }
}

JSValue formatNumeric(JSContext* ctx, const NumberFormatRecord& r, const Numeric& n) {
    UNumberFormatter* f = formatterFor(ctx, r);
    Result result = formatted(f, n);
    const Text16 text = resultText(ctx, result);
    return String::fromUTF16(ctx, text.data(), text.size()).toJS(ctx);
}

JSValue formatNumericToParts(JSContext* ctx, const NumberFormatRecord& r, const Numeric& n) {
    UNumberFormatter* f = formatterFor(ctx, r);
    Result result = formatted(f, n);
    const Text16 text = resultText(ctx, result);
    FieldIterator fields = openFieldIterator();
    UErrorCode status = U_ZERO_ERROR;
    unumf_resultGetAllFieldPositions(result.get(), fields.get(), &status);
    if (U_FAILURE(status)) {
        throw RangeError{std::string("Intl.NumberFormat: ICU failed: ") + u_errorName(status)};
    }
    return partsFromFields(ctx, text, fields.get(), partType, &n);
}

JSClassID numberFormatClass(JSContext* ctx) {
    return intlState(ctx).classIds[size_t(IntlClass::NumberFormat)];
}

JSValue boundFormat(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv, int, JSValueConst* data) {
    return glue(ctx, [&]() -> JSValue {
        NumberFormatObject& nf = intlReceiver<NumberFormatObject>(ctx, data[0], numberFormatClass(ctx), "format");
        const Numeric n = toIntlMathematicalValue(ctx, argc > 0 ? argv[0] : JS_UNDEFINED);
        return formatNumeric(ctx, nf.record, n);
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
        return formatNumericToParts(ctx, nf.record, n);
    });
}

void defineString(JSContext* ctx, JSValueConst object, const char* name, std::string_view value) {
    check(ctx, JS_DefinePropertyValueStr(ctx, object, name, JS_NewStringLen(ctx, value.data(), value.size()), JS_PROP_C_W_E));
}
void defineInt(JSContext* ctx, JSValueConst object, const char* name, int value) {
    check(ctx, JS_DefinePropertyValueStr(ctx, object, name, JS_NewInt32(ctx, value), JS_PROP_C_W_E));
}
const char* at(std::initializer_list<const char*> list, size_t index) {
    return *(list.begin() + std::ptrdiff_t(index));
}

JSValue resolvedOptions(JSContext* ctx, JSValueConst thisVal, int, JSValueConst*) {
    return glue(ctx, [&]() -> JSValue {
        const NumberFormatRecord& r = intlReceiver<NumberFormatObject>(ctx, thisVal, numberFormatClass(ctx),
                                                                       "Intl.NumberFormat.prototype.resolvedOptions")
                                          .record;
        Value o = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
        defineString(ctx, o.get(), "locale", r.locale);
        defineString(ctx, o.get(), "numberingSystem", r.numberingSystem);
        defineString(ctx, o.get(), "style", at(kStyles, r.style));
        if (r.style == Currency) {
            defineString(ctx, o.get(), "currency", r.currency);
            defineString(ctx, o.get(), "currencyDisplay", at(kCurrencyDisplays, r.currencyDisplay));
            defineString(ctx, o.get(), "currencySign", at(kCurrencySigns, r.currencySign));
        }
        if (r.style == Unit) {
            defineString(ctx, o.get(), "unit", r.unit);
            defineString(ctx, o.get(), "unitDisplay", at(kUnitDisplays, r.unitDisplay));
        }
        defineDigitCounts(ctx, o.get(), r.digits);
        if (r.useGrouping == GroupingOff) {
            check(ctx, JS_DefinePropertyValueStr(ctx, o.get(), "useGrouping", JS_FALSE, JS_PROP_C_W_E));
        } else {
            defineString(ctx, o.get(), "useGrouping", at(kGroupings, size_t(r.useGrouping)));
        }
        defineString(ctx, o.get(), "notation", at(kNotations, size_t(r.notation)));
        if (r.notation == Notation::Compact) {
            defineString(ctx, o.get(), "compactDisplay", at(kCompactDisplays, r.compactDisplay));
        }
        defineString(ctx, o.get(), "signDisplay", at(kSignDisplays, r.signDisplay));
        defineRoundingOptions(ctx, o.get(), r.digits);
        return o.release();
    });
}

JSValue construct(JSContext* ctx, JSValueConst newTarget, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        const JSClassID id = numberFormatClass(ctx);
        Value proto = prototypeFromConstructor(ctx, newTarget, id);
        const NumberFormatRecord record = initializeNumberFormat(ctx, argc > 0 ? argv[0] : JS_UNDEFINED,
                                                                 argc > 1 ? argv[1] : JS_UNDEFINED);
        return createIntlObject<NumberFormatObject>(ctx, proto.get(), id, record).release();
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

void readDigitOptions(JSContext* ctx, JSValueConst o, int mnfdDefault, int mxfdDefault, Notation notation, DigitOptions& out) {
    out.minimumIntegerDigits = getNumberOption(ctx, o, "minimumIntegerDigits", 1, 21).value_or(1);
    Value mnfd = getRaw(ctx, o, "minimumFractionDigits");
    Value mxfd = getRaw(ctx, o, "maximumFractionDigits");
    Value mnsd = getRaw(ctx, o, "minimumSignificantDigits");
    Value mxsd = getRaw(ctx, o, "maximumSignificantDigits");
    const int increment = getNumberOption(ctx, o, "roundingIncrement", 1, 5000).value_or(1);
    if (std::find(std::begin(kRoundingIncrements), std::end(kRoundingIncrements), increment) == std::end(kRoundingIncrements)) {
        throw RangeError{"Intl: the value of roundingIncrement is out of range."};
    }
    out.roundingMode = uint8_t(optionIndex(getStringOption(ctx, o, "roundingMode", kRoundingModes), kRoundingModes, 6));
    const int priority = optionIndex(getStringOption(ctx, o, "roundingPriority", kRoundingPriorities), kRoundingPriorities, 0);
    out.stripIfInteger = optionIndex(getStringOption(ctx, o, "trailingZeroDisplay", kTrailingZeroDisplays), kTrailingZeroDisplays, 0) == 1;
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
            out.minimumSignificantDigits = defaultNumberOption(ctx, mnsd, 1, 21, "minimumSignificantDigits").value_or(1);
            out.maximumSignificantDigits =
                defaultNumberOption(ctx, mxsd, out.minimumSignificantDigits, 21, "maximumSignificantDigits").value_or(21);
        } else {
            out.minimumSignificantDigits = 1;
            out.maximumSignificantDigits = 21;
        }
    }
    if (needFd) {
        if (hasFd) {
            std::optional<int> min = defaultNumberOption(ctx, mnfd, 0, 100, "minimumFractionDigits");
            std::optional<int> max = defaultNumberOption(ctx, mxfd, 0, 100, "maximumFractionDigits");
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

std::u16string digitsSkeleton(const DigitOptions& d) {
    std::string s;
    if (d.minimumIntegerDigits > 1) {
        s += "integer-width/*" + std::string(size_t(d.minimumIntegerDigits), '0') + " ";
    }
    std::string precision;
    if (d.roundingIncrement != 1) {
        precision = "precision-increment/" + incrementStem(d.roundingIncrement, d.maximumFractionDigits);
    } else {
        switch (d.roundingType) {
        case RoundingType::FractionDigits:
            precision = fractionStem(d.minimumFractionDigits, d.maximumFractionDigits);
            break;
        case RoundingType::SignificantDigits:
            precision = significantStem(d.minimumSignificantDigits, d.maximumSignificantDigits);
            break;
        case RoundingType::MorePrecision:
        case RoundingType::LessPrecision:
            precision = fractionStem(d.minimumFractionDigits, d.maximumFractionDigits) + "/" +
                        significantStem(d.minimumSignificantDigits, d.maximumSignificantDigits) +
                        (d.roundingType == RoundingType::MorePrecision ? "r" : "s");
            break;
        }
    }
    if (d.stripIfInteger) {
        precision += "/w";
    }
    s += precision + " rounding-mode-" + kICURoundingModes[d.roundingMode];
    return toU16(s);
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
    defineString(ctx, o, "roundingMode", at(kRoundingModes, d.roundingMode));
    defineString(ctx, o, "roundingPriority", at(kRoundingPriorities, d.computedRoundingPriority));
    defineString(ctx, o, "trailingZeroDisplay", at(kTrailingZeroDisplays, d.stripIfInteger ? 1 : 0));
}

JSValue formatNumberToLocaleString(JSContext* ctx, JSValueConst x, JSValueConst locales, JSValueConst options) {
    const NumberFormatRecord record = initializeNumberFormat(ctx, locales, options);
    const Numeric n = toIntlMathematicalValue(ctx, x);
    return formatNumeric(ctx, record, n);
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
