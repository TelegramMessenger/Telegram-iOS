// Intl (V5b plan; ECMA-402, 2024 edition) over the system ICU: what the Intl*.cpp files share. The constructors are
// hand-built QuickJS classes (an ECMA-402 object is not a WebIDL one); each reads its options into a fixed-size record,
// its payload, and opens ICU only to format, through the per-runtime IntlCache.
#pragma once

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <initializer_list>
#include <list>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "quickjs.h"
#include "Sources/Host/Encoding.h"
#include "Sources/Host/ICU.h"
#include "Sources/Support/Allocator.h"
#include "Sources/Support/Errors.h"
#include "Sources/Support/Values.h"

namespace wr::intl {

/// ICU handles kept per runtime; the least recently used goes beyond this.
inline constexpr size_t kIntlCacheSize = 32;
/// The longest string handed to ICU, in UTF-16 units; longer is a RangeError.
inline constexpr uint32_t kMaxIntlString = uint32_t(1) << 20;
/// The longest locale tag read, in bytes (ICU's ULOC_FULLNAME_CAPACITY); longer is a RangeError.
inline constexpr size_t kMaxLocaleTag = ULOC_FULLNAME_CAPACITY;
/// The most distinct tags a locale list may hold; more is a RangeError (V5b final review, C1).
inline constexpr size_t kMaxLocaleList = 128;
/// The most items ListFormat.format reads; more is a RangeError (V5b final review, I1: units alone let a million empty
/// strings through).
inline constexpr size_t kMaxListItems = 10000;

/// ICU handles by key (the resolved record a format needs). A handle is owned here and closed when evicted or when the
/// runtime goes; a JS object never holds one. A pointer get returns stays valid for the next kIntlCacheSize - 1 gets.
class IntlCache {
public:
    IntlCache() = default;
    IntlCache(const IntlCache&) = delete;
    IntlCache& operator=(const IntlCache&) = delete;
    ~IntlCache();

    /// The handle cached under `key`, or the one `opener` makes, charged work::kIntlOpen first. `opener` returns nullptr
    /// when ICU refuses; nothing is cached then. Throws Thrown when the charge stops the widget.
    template <class T, class Open>
    T* get(JSContext* ctx, const std::string& key, Open opener, void (*close)(T*)) {
        if (void* found = this->find(key)) {
            return static_cast<T*>(found);
        }
        this->chargeOpen(ctx);
        T* handle = opener();
        if (handle) {
            this->insert(key, handle, reinterpret_cast<void (*)(void*)>(close));
        }
        return handle;
    }
    size_t size() const { return m_entries.size(); }

private:
    struct Entry {
        std::string key;
        void* handle;
        void (*close)(void*);
    };
    void* find(const std::string& key);
    void insert(const std::string& key, void* handle, void (*close)(void*));
    static void chargeOpen(JSContext* ctx);
    std::list<Entry> m_entries;  // the most recently used first
};

/// The Intl state of a runtime, in its HostState.
struct IntlState {
    explicit IntlState(JSRuntime* rt) : rt(rt) {}
    ~IntlState() { intl.clear(rt); }
    JSRuntime* rt;
    IntlCache cache;
    /// The runtime's own Intl object (intlObject), JS_UNDEFINED until first made.
    Held intl;
    /// By IntlClass; allocated per runtime, 0 until registered.
    JSClassID classIds[6] = {};
};

IntlState& intlState(JSContext* ctx);

/// ECMA-402 CanonicalizeLocaleList: the canonical BCP 47 tags of `locales`, deduplicated, in order. Charges
/// work::kNodeVisit per index read. Throws TypeError (an entry neither a string nor an object), RangeError (not a
/// structurally valid tag, or longer than kMaxLocaleTag) and Thrown.
std::vector<std::string> canonicalizeLocaleList(JSContext* ctx, JSValueConst locales);
/// ECMA-402 ResolveLocale's locale: the first requested tag that BestAvailableLocale finds among ICU's available
/// locales (unicode extensions dropped), else the host's locale (HostState::locale()) resolved the same way, else
/// "en-US".
std::string resolveLocale(JSContext* ctx, const std::vector<std::string>& requested);
/// ECMA-402 SupportedLocales, for every supportedLocalesOf: a new array. Throws Thrown.
JSValue supportedLocales(JSContext* ctx, JSValueConst locales, JSValueConst options);

/// ECMA-402 CoerceOptionsToObject: a null-prototype object for undefined, else ToObject. A new reference. Throws Thrown.
Value coerceOptionsToObject(JSContext* ctx, JSValueConst options);
/// ECMA-402 GetOption for a string: nullopt when the property is undefined; RangeError when `allowed` is not empty and
/// lacks the value, or when it is longer than `maxLength` units (every free-form option has a grammar shorter than the
/// default). Throws Thrown.
std::optional<std::string> getStringOption(JSContext* ctx, JSValueConst options, const char* name,
                                           std::initializer_list<const char*> allowed, size_t maxLength = 64);
/// ECMA-402 GetOption for a boolean: nullopt when undefined, else ToBoolean. Throws Thrown.
std::optional<bool> getBooleanOption(JSContext* ctx, JSValueConst options, const char* name);
/// ECMA-402 GetNumberOption: nullopt when undefined; RangeError when NaN or outside [min, max]; floor. Throws Thrown.
std::optional<int> getNumberOption(JSContext* ctx, JSValueConst options, const char* name, int min, int max);

// ───────────── the classes

enum class IntlClass : uint8_t { NumberFormat, DateTimeFormat, PluralRules, RelativeTimeFormat, ListFormat, Collator };

/// What every Intl object's payload has: its cached bound function (format, compare), JS_UNDEFINED until first read.
struct IntlObjectBase {
    JSValue bound = JS_UNDEFINED;
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
/// Copies `value` into `out` (cut to N - 1 bytes; callers have checked the length).
template <size_t N>
void copyInto(char (&out)[N], std::string_view value) {
    const size_t n = std::min(value.size(), N - 1);
    std::copy(value.begin(), value.begin() + std::ptrdiff_t(n), out);
    out[n] = 0;
}
/// The index of `value` in `allowed` (ECMA-402 GetOption's list), or `fallback` when the option was undefined.
int optionIndex(const std::optional<std::string>& value, std::initializer_list<const char*> allowed, int fallback);
/// A UTF-16 result of ICU, in the JS heap: `produce(buffer, capacity, status)` is called to fill, and again with room
/// enough when ICU reports an overflow, as ICU's *_format / *ToString calls work. Throws RangeError when ICU fails or
/// the result passes kMaxIntlString.
template <class Produce>
Text16 icuText(JSContext* ctx, Produce produce);
/// icuText as a JS string: a new reference.
template <class Produce>
JSValue icuString(JSContext* ctx, Produce produce) {
    const Text16 text = icuText(ctx, produce);
    return String::fromUTF16(ctx, text.data(), text.size()).toJS(ctx);
}

/// `string`'s UTF-16 units, in the JS heap; a RangeError past kMaxIntlString units, the copy charged as a scan.
Text16 utf16Of(JSContext* ctx, const String& string);
/// Whether this device's libicucore has every function ICU.h declares (they are weak imports): Intl installs only then.
bool icuAvailable();
/// Whether ICU has the numbering system `name` as a simple digit system (ECMA-402's available numbering systems;
/// ICU's algorithmic ones, roman or hebr, are not digits).
bool isSupportedNumberingSystem(const std::string& name);
/// The ICU locale id of a BCP 47 tag ("en_US" for "en-US"); "en_US" when ICU cannot read it.
std::string toICULocale(const std::string& tag);
/// A UFieldPositionIterator, closed on scope exit.
using FieldIterator = std::unique_ptr<UFieldPositionIterator, void (*)(UFieldPositionIterator*)>;
/// A new iterator. Throws RangeError when ICU fails.
FieldIterator openFieldIterator();
/// ECMA-402's parts of ICU's output `text`, from `fields` (filled by the format call): each code unit given its
/// innermost field (-1 for none), a part per run of one field, typed by `type(field, value, context)`. A new array.
/// Charges work::kNodeVisit per field. Throws.
using PartType = const char* (*)(int field, std::u16string_view value, const void* context);
JSValue partsFromFields(JSContext* ctx, const Text16& text, UFieldPositionIterator* fields, PartType type,
                        const void* context);

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
/// Reads the digit options in ECMA-402's order (minimumIntegerDigits … trailingZeroDisplay) into `out`. Throws.
void readDigitOptions(JSContext* ctx, JSValueConst options, int mnfdDefault, int mxfdDefault, Notation notation,
                      DigitOptions& out);
/// The ICU skeleton stems for `digits`: integer width, precision, rounding mode.
std::u16string digitsSkeleton(const DigitOptions& digits);
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
/// String.prototype.localeCompare.
void installStringOverrides(JSContext* ctx);

/// The runtime's own Intl object, made on first use: a new reference. The lazy global answers with it, and the
/// locale-sensitive overrides reach the constructors through it, never through `globalThis.Intl`. Throws Thrown.
JSValue intlObject(JSContext* ctx);
/// Defines the lazy global `Intl`. Called by installHost.
void installIntl(JSContext* ctx);

template <class Produce>
Text16 icuText(JSContext* ctx, Produce produce) {
    Text16 buffer{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
    buffer.resize(128);
    UErrorCode status = U_ZERO_ERROR;
    int32_t length = produce(buffer.data(), int32_t(buffer.size()), &status);
    if (status == U_BUFFER_OVERFLOW_ERROR || status == U_STRING_NOT_TERMINATED_WARNING) {
        if (length < 0 || uint32_t(length) > kMaxIntlString) {
            throw RangeError{"Intl: the result is too long."};
        }
        buffer.resize(size_t(length) + 1);
        status = U_ZERO_ERROR;
        length = produce(buffer.data(), int32_t(buffer.size()), &status);
    }
    if (U_FAILURE(status) || length < 0) {
        throw RangeError{std::string("Intl: ICU failed: ") + u_errorName(status)};
    }
    buffer.resize(size_t(length));
    return buffer;
}

} // namespace wr::intl
