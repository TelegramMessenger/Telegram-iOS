// Intl (V5b plan; ECMA-402, 2024 edition) over widget-sandbox's `intl` capability (Host::intl): what the Intl*.cpp
// files share. The constructors are hand-built QuickJS classes (an ECMA-402 object is not a WebIDL one); each reads its
// options in ECMA-402's order, refusing what ECMA-402 refuses, and keeps the ones the widget gave. Every answer that
// needs locale data is the host's, to the request widget-sandbox's shim sends for the same call: `{"kind":…,
// "locale":…,"opts":{…},…}` with the given options (a date format's with the shim's defaults added), its glue's answer
// back. The app's host is that glue itself (widget-sandbox's iOS IntlBridge, Foundation's formatters): ICU's formatting
// API is not public on iOS (Sources/Host/ICU.h).
#pragma once

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <initializer_list>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "quickjs.h"
#include "Sources/Host/Encoding.h"
#include "Sources/Support/Allocator.h"
#include "Sources/Support/Errors.h"
#include "Sources/Support/Values.h"

namespace wr::intl {

/// The longest string handed to the host, in UTF-16 units (a list's items together); longer is a RangeError.
inline constexpr uint32_t kMaxIntlString = uint32_t(1) << 20;
/// The longest answer taken from the host, in bytes; longer is a RangeError.
inline constexpr size_t kMaxIntlAnswer = size_t(4) << 20;
/// The longest locale tag read, in bytes (ICU's ULOC_FULLNAME_CAPACITY); longer is a RangeError.
inline constexpr size_t kMaxLocaleTag = 157;
/// The most distinct tags a locale list may hold; more is a RangeError (V5b final review, C1).
inline constexpr size_t kMaxLocaleList = 128;
/// The most items ListFormat.format reads; more is a RangeError (V5b final review, I1: units alone let a million empty
/// strings through).
inline constexpr size_t kMaxListItems = 10000;

/// The Intl state of a runtime, in its HostState.
struct IntlState {
    explicit IntlState(JSRuntime* rt) : rt(rt) {}
    ~IntlState() { intl.clear(rt); }
    JSRuntime* rt;
    /// The runtime's own Intl object (intlObject), JS_UNDEFINED until first made.
    Held intl;
    /// By IntlClass; allocated per runtime, 0 until registered.
    JSClassID classIds[6] = {};
};

IntlState& intlState(JSContext* ctx);

/// ECMA-402 CanonicalizeLocaleList: the canonical BCP 47 tags of `locales` (UTS 35's case: language and extensions in
/// lower case, a script in title case, a region in upper case), deduplicated, in order. Throws TypeError (an entry
/// neither a string nor an object), RangeError (not a structurally valid tag, or longer than kMaxLocaleTag) and Thrown.
std::vector<std::string> canonicalizeLocaleList(JSContext* ctx, JSValueConst locales);
/// ECMA-402's [[RelevantExtensionKeys]] of the constructor a locale is resolved for: NumberFormat and RelativeTimeFormat
/// read nu; DateTimeFormat ca, hc and nu; Collator co, kf and kn; PluralRules and ListFormat none.
enum class RelevantKeys : uint8_t { None, NumberFormat, DateTimeFormat, RelativeTimeFormat, Collator };
/// The locale a request names (ECMA-402 ResolveLocale): the first requested tag, else the host's locale
/// (HostState::locale(), the app's language) when it is a valid tag, else "en-US". Its unicode extension keeps only the
/// keywords `keys` names, each with a value this client supports (kNumberingSystems and the other tables in
/// IntlCore.cpp), sorted by key; attributes, anything else, other extensions and private use are dropped. The
/// glue builds its locale with Locale.Components (iOS 16 and later; before, it drops the extension) and applies what is
/// left. A value it does not know is never sent: a numbering system name Foundation does not know (bogus, a bare `nu`,
/// yes) makes its RelativeDateTimeFormatter trap, and the glue reads plural rules from a language key an extension
/// breaks (follow-ups review, C1 and I1); algorithmic systems (jpanfin, hanidays) are not in the table either.
/// WRIntlExtensionTests runs every call a widget can make on iOS.
/// With no list of available locales here, every structurally valid tag is taken as one (widget-sandbox's shim does
/// the same).
std::string resolveLocale(JSContext* ctx, const std::vector<std::string>& requested, RelevantKeys keys);
/// ECMA-402 SupportedLocales, for every supportedLocalesOf: the canonical requested tags, a new array. Throws Thrown.
JSValue supportedLocales(JSContext* ctx, JSValueConst locales, JSValueConst options);

/// The options a widget gave, in the order they were read, as the members of a request's "opts" object (in the JS
/// heap): a string option's string, a number option's number after its range check, a boolean option's boolean.
class GivenOptions {
public:
    explicit GivenOptions(JSContext* ctx) : m_members(JSAllocator<char>(JS_GetRuntime(ctx))) {}
    void addString(const char* name, std::string_view utf8);
    void addNumber(JSContext* ctx, const char* name, double value);
    void addBool(const char* name, bool value);
    /// `{…}`.
    JSText json() const;

private:
    JSText m_members;
};

/// ECMA-402 CoerceOptionsToObject: a null-prototype object for undefined, else ToObject. A new reference. Throws Thrown.
Value coerceOptionsToObject(JSContext* ctx, JSValueConst options);
/// ECMA-402 GetOption for a string: nullopt when the property is undefined; RangeError when `allowed` is not empty and
/// lacks the value, or when it is longer than `maxLength` units (every free-form option has a grammar shorter than the
/// default). A defined value is added to `given`. Throws Thrown.
std::optional<std::string> getStringOption(JSContext* ctx, JSValueConst options, const char* name,
                                           std::initializer_list<const char*> allowed, GivenOptions* given = nullptr,
                                           size_t maxLength = 64);
/// ECMA-402 GetOption for a boolean: nullopt when undefined, else ToBoolean, added to `given`. Throws Thrown.
std::optional<bool> getBooleanOption(JSContext* ctx, JSValueConst options, const char* name, GivenOptions* given = nullptr);
/// ECMA-402 GetNumberOption: nullopt when undefined; RangeError when NaN or outside [min, max]; floor, added to `given`.
/// Throws Thrown.
std::optional<int> getNumberOption(JSContext* ctx, JSValueConst options, const char* name, int min, int max,
                                   GivenOptions* given = nullptr);

/// A request of the `intl` capability, written as the shim's JSON.stringify writes it: `{"kind":…`, then the members in
/// the order added. Never through JS_JSONStringify, which would run a widget's toJSON. In the JS heap.
class IntlRequest {
public:
    IntlRequest(JSContext* ctx, const char* kind);
    IntlRequest& string(const char* name, std::string_view utf8);
    /// A JS string, an unpaired surrogate as U+FFFD (the glue reads UTF-8).
    IntlRequest& string(const char* name, const String& value);
    /// As JSON.stringify writes a number: null when it is not finite.
    IntlRequest& number(const char* name, double value);
    /// `json` as it is: the given options, a list.
    IntlRequest& raw(const char* name, std::string_view json);
    /// Asks the host. Throws RangeError for an answer longer than kMaxIntlAnswer, and Thrown.
    std::string send();

private:
    void name(const char* name);
    JSContext* m_ctx;
    JSText m_json;
};

/// Appends `utf8` to `out` as a JSON string.
void appendJSONString(JSText& out, std::string_view utf8);
/// The host's answer as a JS string: a new reference.
JSValue answerString(JSContext* ctx, std::string_view answer);
/// The host's answer parsed as JSON when it is an array (formatToParts) or an object (resolvedOptions), as `array`
/// asks; else a new empty one, the shim's fallback. A new reference. Throws Thrown.
Value answerJSON(JSContext* ctx, const std::string& answer, bool array);
/// resolvedOptions' object: for each of `keys`, in order, the host's value when `answer` has the key, else ours when
/// `ours` has it, else none. A new reference. Throws Thrown.
JSValue mergedOptions(JSContext* ctx, JSValueConst answer, JSValueConst ours, std::initializer_list<const char*> keys);

// ───────────── the classes

enum class IntlClass : uint8_t { NumberFormat, DateTimeFormat, PluralRules, RelativeTimeFormat, ListFormat, Collator };

/// What every Intl object's payload has: its cached bound function (format, compare), JS_UNDEFINED until first read,
/// and the locale and given options its requests carry.
struct IntlObjectBase {
    IntlObjectBase(std::string_view locale, JSText opts) : opts(std::move(opts)) { copyInto(this->locale, locale); }
    JSValue bound = JS_UNDEFINED;
    char locale[kMaxLocaleTag + 1] = {};
    JSText opts;

private:
    static void copyInto(char (&out)[kMaxLocaleTag + 1], std::string_view value) {
        const size_t n = std::min(value.size(), kMaxLocaleTag);
        std::copy(value.begin(), value.begin() + std::ptrdiff_t(n), out);
        out[n] = 0;
    }
};
/// Destroys a T payload made by createIntlObject: the class's finalizer.
template <class T>
void finalizeIntlObject(JSRuntime* rt, JSValueConst value) {
    JSClassID id = 0;
    if (T* payload = static_cast<T*>(JS_GetAnyOpaque(value, &id))) {
        JS_FreeValueRT(rt, static_cast<IntlObjectBase*>(payload)->bound);
        payload->~T();
        js_free_rt(rt, payload);
    }
}
/// Marks a T payload's bound function: the object → bound function → object cycle is collectable.
template <class T>
void markIntlObject(JSRuntime* rt, JSValueConst value, JS_MarkFunc* mark) {
    JSClassID id = 0;
    if (T* payload = static_cast<T*>(JS_GetAnyOpaque(value, &id))) {
        JS_MarkValue(rt, static_cast<IntlObjectBase*>(payload)->bound, mark);
    }
}
/// Registers `which`'s class on this runtime (once; IntlState::classIds) and returns its id.
JSClassID registerIntlClass(JSContext* ctx, IntlClass which, const char* name, JSClassFinalizer* finalizer,
                            JSClassGCMark* mark);
/// Defines the constructor `name` on `intl`: `constructor` (JS_CFUNC_constructor_or_func: new.target is undefined when
/// it is called as a function), its prototype (the class's, with `prototypeMembers`, among them the class string) and
/// `supportedLocalesOf`. Throws Thrown.
void defineIntlConstructor(JSContext* ctx, JSValueConst intl, JSClassID id, const char* name, JSCFunction* constructor,
                           int length, const JSCFunctionListEntry* prototypeMembers, int memberCount);
/// ECMA-402's GetPrototypeFromConstructor: newTarget.prototype when it is an object, else the class's prototype. A new
/// reference. Throws Thrown.
Value prototypeFromConstructor(JSContext* ctx, JSValueConst newTarget, JSClassID id);
/// An object of class `id` with prototype `proto` whose payload is a new T(args...) in js_malloc'd memory. Throws Thrown.
template <class T, class... A>
Value createIntlObject(JSContext* ctx, JSValueConst proto, JSClassID id, A&&... args) {
    Value object = Value::adopt(ctx, JS_NewObjectProtoClass(ctx, proto, id));
    if (JS_IsException(object.get())) {
        throw Thrown{};
    }
    void* memory = js_malloc(ctx, sizeof(T));
    if (!memory) {
        throw Thrown{};
    }
    JS_SetOpaque(object.get(), new (memory) T(std::forward<A>(args)...));
    return object;
}
/// The T payload of `value` when it is an object of class `id`, else a TypeError naming `method`. Throws.
template <class T>
T& intlReceiver(JSContext* ctx, JSValueConst value, JSClassID id, const char* method) {
    T* payload = static_cast<T*>(JS_GetOpaque(value, id));
    if (!payload) {
        throw TypeError{std::string(method) + ": the receiver is not of the right Intl class."};
    }
    return *payload;
}
/// A bound function of `function` with `target` as its one datum (ECMA-402's bound format and compare): `length`, no
/// name. A new reference. Throws Thrown.
JSValue boundIntlFunction(JSContext* ctx, JSCFunctionData* function, int length, JSValueConst target);
/// The index of `value` in `allowed` (ECMA-402 GetOption's list), or `fallback` when the option was undefined.
int optionIndex(const std::optional<std::string>& value, std::initializer_list<const char*> allowed, int fallback);
/// `allowed`'s entry at `index`.
const char* optionAt(std::initializer_list<const char*> allowed, size_t index);
/// Defines a string, number or boolean data property: resolvedOptions' entries. Throw Thrown.
void defineString(JSContext* ctx, JSValueConst object, const char* name, std::string_view value);
void defineInt(JSContext* ctx, JSValueConst object, const char* name, int value);
void defineBool(JSContext* ctx, JSValueConst object, const char* name, bool value);
/// UTS 35's type (3*8alphanum) *("-" (3*8alphanum)): calendar, collation and numbering system values.
bool isUnicodeType(std::string_view type);

/// `string`'s UTF-16 units, in the JS heap; a RangeError past kMaxIntlString units.
Text16 utf16Of(JSContext* ctx, const String& string);

// ───────────── NumberFormat (IntlNumberFormat.cpp)

enum class Notation : uint8_t { Standard, Scientific, Engineering, Compact };
enum class RoundingType : uint8_t { FractionDigits, SignificantDigits, MorePrecision, LessPrecision };

/// ECMA-402 SetNumberFormatDigitOptions' result.
struct DigitOptions {
    int minimumIntegerDigits = 1;
    int minimumFractionDigits = 0;
    int maximumFractionDigits = 3;
    int minimumSignificantDigits = 1;
    int maximumSignificantDigits = 21;
    int roundingIncrement = 1;
    uint8_t roundingMode = 6;  // the index in the roundingMode list: halfExpand
    bool stripIfInteger = false;
    RoundingType roundingType = RoundingType::FractionDigits;
    uint8_t computedRoundingPriority = 0;  // auto, morePrecision, lessPrecision
};
/// Reads the digit options in ECMA-402's order (minimumIntegerDigits … trailingZeroDisplay) into `out`, the defined
/// ones into `given`. Throws.
void readDigitOptions(JSContext* ctx, JSValueConst options, int mnfdDefault, int mxfdDefault, Notation notation,
                      DigitOptions& out, GivenOptions* given);
/// resolvedOptions' digit entries, in ECMA-402's order: minimumIntegerDigits, then the fraction and the significant
/// digits the rounding type uses.
void defineDigitCounts(JSContext* ctx, JSValueConst object, const DigitOptions& digits);
/// resolvedOptions' rounding entries: roundingIncrement, roundingMode, roundingPriority, trailingZeroDisplay.
void defineRoundingOptions(JSContext* ctx, JSValueConst object, const DigitOptions& digits);
/// Number.prototype.toLocaleString and BigInt.prototype.toLocaleString's work for `x` (already the primitive):
/// a NumberFormat of `locales` and `options`, then FormatNumeric. A new reference. Throws.
JSValue formatNumberToLocaleString(JSContext* ctx, JSValueConst x, JSValueConst locales, JSValueConst options);
/// Defines Intl.NumberFormat on `intl`, and the toLocaleString overrides (installNumberOverrides). Throws Thrown.
void defineNumberFormat(JSContext* ctx, JSValueConst intl);
void installNumberOverrides(JSContext* ctx);

// ───────────── DateTimeFormat (IntlDateTimeFormat.cpp)

/// ECMA-402 CreateDateTimeFormat's required and defaults: toLocaleString's any/all, toLocaleDateString's date/date,
/// toLocaleTimeString's time/time, and the constructor's any/date.
enum class DateDefaults : uint8_t { Any, Date, Time, Constructor };
/// Date.prototype.toLocale{String,DateString,TimeString}'s work for a time value already read (NaN gives "Invalid
/// Date"). A new reference. Throws.
JSValue formatDateToLocaleString(JSContext* ctx, double timeValue, JSValueConst locales, JSValueConst options,
                                 DateDefaults which);
void defineDateTimeFormat(JSContext* ctx, JSValueConst intl);
void installDateOverrides(JSContext* ctx);

// ───────────── PluralRules, RelativeTimeFormat, ListFormat, Collator (IntlText.cpp)

void defineTextFormats(JSContext* ctx, JSValueConst intl);
/// String.prototype.localeCompare, toLocaleUpperCase and toLocaleLowerCase.
void installStringOverrides(JSContext* ctx);

/// The runtime's own Intl object, made on first use: a new reference. The lazy global answers with it, and the
/// locale-sensitive overrides reach the constructors through it, never through `globalThis.Intl`. Throws Thrown.
JSValue intlObject(JSContext* ctx);
/// Defines the lazy global `Intl`. Called by installHost.
void installIntl(JSContext* ctx);

} // namespace wr::intl
