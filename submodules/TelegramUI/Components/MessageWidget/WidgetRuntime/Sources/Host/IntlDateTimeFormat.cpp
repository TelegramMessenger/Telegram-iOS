// Intl.DateTimeFormat (V5b plan, Task 3; ECMA-402 §11) and Date.prototype.toLocale{String,DateString,TimeString}: the
// options read in ECMA-402's order and the ones given kept, with ToDateTimeOptions' defaults added as widget-sandbox's
// shim adds them (its glue formats only the fields it is given), then the host's `date`, `dateMethod`, `dateParts` and
// `dateOptions` requests (Sources/Host/Intl.h).
#include <cctype>
#include <cmath>
#include <string>
#include <string_view>

#include "Sources/Host/Intl.h"
#include "Sources/Runtime/Runtime.h"

namespace wr::intl {

namespace {

enum Component : uint8_t { Weekday, Era, Year, Month, Day, DayPeriod, Hour, Minute, Second, FractionalSecondDigits, TimeZoneName, ComponentCount };

const char* const kComponentNames[ComponentCount] = {"weekday", "era",    "year",   "month",
                                                     "day",     "dayPeriod", "hour", "minute",
                                                     "second",  "fractionalSecondDigits", "timeZoneName"};
const std::initializer_list<const char*> kTextual = {"narrow", "short", "long"};
const std::initializer_list<const char*> kNumeric = {"2-digit", "numeric"};
const std::initializer_list<const char*> kMonths = {"2-digit", "numeric", "narrow", "short", "long"};
const std::initializer_list<const char*> kZoneNames = {"short", "long", "shortOffset", "longOffset", "shortGeneric", "longGeneric"};
const std::initializer_list<const char*> kHourCycles = {"h11", "h12", "h23", "h24"};
const std::initializer_list<const char*> kStyles = {"full", "long", "medium", "short"};

std::initializer_list<const char*> allowedFor(Component c) {
    switch (c) {
    case Weekday:
    case Era:
    case DayPeriod:
        return kTextual;
    case Month:
        return kMonths;
    case TimeZoneName:
        return kZoneNames;
    default:
        return kNumeric;
    }
}

struct DateTimeFormatObject : IntlObjectBase {
    DateTimeFormatObject(std::string_view locale, JSText opts) : IntlObjectBase(locale, std::move(opts)) {}
};

/// An IANA time zone name or a link to one, as far as its characters go ("Europe/Paris", "UTC", "Etc/GMT+3"): the host
/// knows which exist (the glue formats an unknown one in the device's zone). An offset ("+01:00") is not one.
bool isTimeZoneName(std::string_view name) {
    if (name.empty()) {
        return false;
    }
    for (char c : name) {
        if (!(std::isalnum(uint8_t(c)) || c == '/' || c == '_' || c == '-' || c == '+')) {
            return false;
        }
    }
    return std::isalpha(uint8_t(name.front()));
}

/// What CreateDateTimeFormat makes: the locale the requests name and the options given.
struct DateTimeFormatSetup {
    std::string locale;
    JSText opts;
};

/// ECMA-402 CreateDateTimeFormat (2024 edition), without the object: every option in its order, its TypeErrors, then
/// ToDateTimeOptions' defaults.
DateTimeFormatSetup createDateTimeFormat(JSContext* ctx, JSValueConst locales, JSValueConst options, DateDefaults which) {
    GivenOptions given(ctx);
    const std::vector<std::string> requested = canonicalizeLocaleList(ctx, locales);
    Value object = coerceOptionsToObject(ctx, options);
    JSValueConst o = object.get();
    getStringOption(ctx, o, "localeMatcher", {"lookup", "best fit"});
    std::optional<std::string> calendar = getStringOption(ctx, o, "calendar", {}, &given);
    if (calendar && !isUnicodeType(*calendar)) {
        throw RangeError{"Intl: the value of calendar is out of range."};
    }
    std::optional<std::string> numberingSystem = getStringOption(ctx, o, "numberingSystem", {}, &given);
    if (numberingSystem && !isUnicodeType(*numberingSystem)) {
        throw RangeError{"Intl: the value of numberingSystem is out of range."};
    }
    getBooleanOption(ctx, o, "hour12", &given);
    getStringOption(ctx, o, "hourCycle", kHourCycles, &given);
    const std::string locale = resolveLocale(ctx, requested, RelevantKeys::DateTimeFormat);
    std::optional<std::string> zone = getStringOption(ctx, o, "timeZone", {}, &given);
    if (zone && !isTimeZoneName(*zone)) {
        throw RangeError{"Intl.DateTimeFormat: invalid time zone."};
    }
    bool requestedComponents[ComponentCount] = {};
    bool hasExplicitComponents = false;
    for (uint8_t c = 0; c < ComponentCount; c++) {
        if (c == FractionalSecondDigits) {
            requestedComponents[c] = getNumberOption(ctx, o, "fractionalSecondDigits", 1, 3, &given).has_value();
        } else {
            requestedComponents[c] = getStringOption(ctx, o, kComponentNames[c], allowedFor(Component(c)), &given).has_value();
        }
        hasExplicitComponents = hasExplicitComponents || requestedComponents[c];
    }
    getStringOption(ctx, o, "formatMatcher", {"basic", "best fit"});
    const bool dateStyle = getStringOption(ctx, o, "dateStyle", kStyles, &given).has_value();
    const bool timeStyle = getStringOption(ctx, o, "timeStyle", kStyles, &given).has_value();
    if (dateStyle || timeStyle) {
        if (hasExplicitComponents) {
            throw TypeError{"Intl.DateTimeFormat: dateStyle and timeStyle cannot be combined with date-time components."};
        }
        if ((which == DateDefaults::Date && timeStyle) || (which == DateDefaults::Time && dateStyle)) {
            throw TypeError{"Intl.DateTimeFormat: this method does not take that style."};
        }
    } else {
        const bool requiresAny = which == DateDefaults::Any || which == DateDefaults::Constructor;
        bool needDefaults = true;
        if (which == DateDefaults::Date || requiresAny) {
            for (Component c : {Weekday, Year, Month, Day}) {
                needDefaults = needDefaults && !requestedComponents[c];
            }
        }
        if (which == DateDefaults::Time || requiresAny) {
            for (Component c : {DayPeriod, Hour, Minute, Second, FractionalSecondDigits}) {
                needDefaults = needDefaults && !requestedComponents[c];
            }
        }
        if (needDefaults && (which == DateDefaults::Date || which == DateDefaults::Any || which == DateDefaults::Constructor)) {
            given.addString("year", "numeric");
            given.addString("month", "numeric");
            given.addString("day", "numeric");
        }
        if (needDefaults && (which == DateDefaults::Time || which == DateDefaults::Any)) {
            given.addString("hour", "numeric");
            given.addString("minute", "numeric");
            given.addString("second", "numeric");
        }
    }
    return DateTimeFormatSetup{locale, given.json()};
}

/// ECMA-402 FormatDateTime's TimeClip: a RangeError for a time ECMAScript cannot represent.
double clippedTime(double x) {
    if (!std::isfinite(x) || std::fabs(x) > 8.64e15) {
        throw RangeError{"Invalid time value"};
    }
    return std::trunc(x) + 0.0;
}

double timeOf(JSContext* ctx, JSValueConst date) {
    if (JS_IsUndefined(date)) {
        return Runtime::from(ctx).host().wallClockNow();
    }
    double x = 0;
    if (JS_ToFloat64(ctx, &x, date) < 0) {
        throw Thrown{};
    }
    return x;
}

/// The host's answer to `kind` (`method` for dateMethod) for `dtf` at the time `t`, or without one.
std::string ask(JSContext* ctx, const char* kind, const char* method, const DateTimeFormatObject& dtf, const double* t) {
    IntlRequest request(ctx, kind);
    if (method) {
        request.string("method", method);
    }
    request.string("locale", dtf.locale).raw("opts", std::string_view(dtf.opts.data(), dtf.opts.size()));
    if (t) {
        request.number("value", *t);
    }
    return request.send();
}

JSClassID dateTimeFormatClass(JSContext* ctx) {
    return intlState(ctx).classIds[size_t(IntlClass::DateTimeFormat)];
}

JSValue boundFormat(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv, int, JSValueConst* data) {
    return glue(ctx, [&]() -> JSValue {
        DateTimeFormatObject& dtf = intlReceiver<DateTimeFormatObject>(ctx, data[0], dateTimeFormatClass(ctx), "format");
        const double t = clippedTime(timeOf(ctx, argc > 0 ? argv[0] : JS_UNDEFINED));
        return answerString(ctx, ask(ctx, "date", nullptr, dtf, &t));
    });
}

JSValue getFormat(JSContext* ctx, JSValueConst thisVal) {
    return glue(ctx, [&]() -> JSValue {
        DateTimeFormatObject& dtf = intlReceiver<DateTimeFormatObject>(ctx, thisVal, dateTimeFormatClass(ctx),
                                                                      "Intl.DateTimeFormat.prototype.format");
        if (JS_IsUndefined(dtf.bound)) {
            dtf.bound = boundIntlFunction(ctx, boundFormat, 1, thisVal);
        }
        return JS_DupValue(ctx, dtf.bound);
    });
}

JSValue formatToParts(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        DateTimeFormatObject& dtf = intlReceiver<DateTimeFormatObject>(ctx, thisVal, dateTimeFormatClass(ctx),
                                                                      "Intl.DateTimeFormat.prototype.formatToParts");
        const double t = clippedTime(timeOf(ctx, argc > 0 ? argv[0] : JS_UNDEFINED));
        return answerJSON(ctx, ask(ctx, "dateParts", nullptr, dtf, &t), true).release();
    });
}

JSValue resolvedOptions(JSContext* ctx, JSValueConst thisVal, int, JSValueConst*) {
    return glue(ctx, [&]() -> JSValue {
        const DateTimeFormatObject& dtf = intlReceiver<DateTimeFormatObject>(ctx, thisVal, dateTimeFormatClass(ctx),
                                                                            "Intl.DateTimeFormat.prototype.resolvedOptions");
        // Ours: the options given (the defaults among them), the locale, and the calendar and numbering system the glue
        // formats in. The fields a style resolves to, the hour cycle and the default time zone are the host's.
        Value ours = answerJSON(ctx, std::string(dtf.opts.data(), dtf.opts.size()), false);
        defineString(ctx, ours.get(), "locale", dtf.locale);
        defineString(ctx, ours.get(), "calendar", "gregory");
        defineString(ctx, ours.get(), "numberingSystem", "latn");
        Value answer = answerJSON(ctx, ask(ctx, "dateOptions", nullptr, dtf, nullptr), false);
        return mergedOptions(ctx, answer.get(), ours.get(),
                             {"locale", "calendar", "numberingSystem", "timeZone", "hourCycle", "hour12", "weekday", "era",
                              "year", "month", "day", "dayPeriod", "hour", "minute", "second", "fractionalSecondDigits",
                              "timeZoneName", "dateStyle", "timeStyle"});
    });
}

JSValue construct(JSContext* ctx, JSValueConst newTarget, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        const JSClassID id = dateTimeFormatClass(ctx);
        Value proto = prototypeFromConstructor(ctx, newTarget, id);
        DateTimeFormatSetup setup = createDateTimeFormat(ctx, argc > 0 ? argv[0] : JS_UNDEFINED, argc > 1 ? argv[1] : JS_UNDEFINED,
                                                         DateDefaults::Constructor);
        return createIntlObject<DateTimeFormatObject>(ctx, proto.get(), id, setup.locale, std::move(setup.opts)).release();
    });
}

const JSCFunctionListEntry kPrototype[] = {
    JS_CGETSET_DEF("format", getFormat, nullptr),
    JS_CFUNC_DEF("formatToParts", 1, formatToParts),
    JS_CFUNC_DEF("resolvedOptions", 0, resolvedOptions),
    JS_PROP_STRING_DEF("[Symbol.toStringTag]", "Intl.DateTimeFormat", JS_PROP_CONFIGURABLE),
};

const char* const kMethods[] = {"toLocaleString", "toLocaleDateString", "toLocaleTimeString"};

JSValue toLocale(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv, int magic) {
    return glue(ctx, [&]() -> JSValue {
        // thisTimeValue, through the engine's own getTime.
        Value time = Value::adopt(ctx, checked(ctx, JS_Call(ctx, Runtime::from(ctx).intrinsic(Runtime::Intrinsic::DateGetTime), thisVal, 0, nullptr)));
        double x = 0;
        if (JS_ToFloat64(ctx, &x, time.get()) < 0) {
            throw Thrown{};
        }
        return formatDateToLocaleString(ctx, x, argc > 0 ? argv[0] : JS_UNDEFINED, argc > 1 ? argv[1] : JS_UNDEFINED, DateDefaults(magic));
    });
}

} // namespace

JSValue formatDateToLocaleString(JSContext* ctx, double timeValue, JSValueConst locales, JSValueConst options, DateDefaults which) {
    if (timeValue != timeValue) {
        return JS_NewString(ctx, "Invalid Date");
    }
    DateTimeFormatSetup setup = createDateTimeFormat(ctx, locales, options, which);
    const DateTimeFormatObject dtf(setup.locale, std::move(setup.opts));
    const double t = clippedTime(timeValue);
    return answerString(ctx, ask(ctx, "dateMethod", kMethods[size_t(which)], dtf, &t));
}

void defineDateTimeFormat(JSContext* ctx, JSValueConst intl) {
    const JSClassID id = registerIntlClass(ctx, IntlClass::DateTimeFormat, "DateTimeFormat",
                                           finalizeIntlObject<DateTimeFormatObject>, markIntlObject<DateTimeFormatObject>);
    defineIntlConstructor(ctx, intl, id, "DateTimeFormat", construct, 0, kPrototype, int(std::size(kPrototype)));
}

void installDateOverrides(JSContext* ctx) {
    Value global = Value::adopt(ctx, JS_GetGlobalObject(ctx));
    Value constructor = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, global.get(), "Date")));
    Value proto = Value::adopt(ctx, checked(ctx, JS_GetPropertyStr(ctx, constructor.get(), "prototype")));
    for (int i = 0; i < 3; i++) {
        JSValue function = checked(ctx, JS_NewCFunctionMagic(ctx, toLocale, kMethods[i], 0, JS_CFUNC_generic_magic, i));
        check(ctx, JS_DefinePropertyValueStr(ctx, proto.get(), kMethods[i], function, JS_PROP_WRITABLE | JS_PROP_CONFIGURABLE));
    }
}

} // namespace wr::intl
