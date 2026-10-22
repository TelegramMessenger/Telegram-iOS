// Intl.DateTimeFormat (V5b plan, Task 3; ECMA-402 §11) and Date.prototype.toLocale{String,DateString,TimeString}: the
// options read in ECMA-402's order, an ICU skeleton (or a date and time style) turned into a pattern by ICU's pattern
// generator at construction, the resolved fields read back from that pattern, and an ICU date formatter for the
// pattern and time zone taken from the runtime's IntlCache at format time.
#include <cctype>
#include <cmath>
#include <map>
#include <memory>
#include <string>
#include <string_view>

#include "Sources/Host/Intl.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Work.h"

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

/// The longest ICU pattern kept, in UTF-16 units; a longer one is a RangeError.
constexpr int32_t kMaxPattern = 128;

struct DateTimeFormatRecord {
    char locale[kMaxLocaleTag + 1] = {};
    char icuLocale[ULOC_FULLNAME_CAPACITY + 1] = {};
    char calendar[32] = {};
    char numberingSystem[16] = {};
    char timeZone[65] = {};
    char16_t pattern[kMaxPattern + 1] = {};
    int32_t patternLength = 0;
    int8_t hourCycle = -1;  // kHourCycles, -1 without an hour
    int8_t components[ComponentCount];
    int8_t dateStyle = -1;
    int8_t timeStyle = -1;
    DateTimeFormatRecord() { std::fill(std::begin(components), std::end(components), int8_t(-1)); }
    std::u16string_view zone16(char16_t (&out)[65]) const {
        size_t n = 0;
        for (; timeZone[n]; n++) {
            out[n] = char16_t(uint8_t(timeZone[n]));
        }
        return std::u16string_view(out, n);
    }
};

struct DateTimeFormatObject : IntlObjectBase {
    explicit DateTimeFormatObject(const DateTimeFormatRecord& record) : record(record) {}
    DateTimeFormatRecord record;
};

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

std::string lowered(std::string_view s) {
    std::string out(s);
    for (char& c : out) {
        c = char(std::tolower(uint8_t(c)));
    }
    return out;
}

/// ICU's time zones by their lower-cased names, once per process (ECMA-402 matches IANA names case-insensitively).
const std::map<std::string, std::string>& timeZonesByName() {
    static const std::map<std::string, std::string> zones = [] {
        std::map<std::string, std::string> out;
        UErrorCode status = U_ZERO_ERROR;
        std::unique_ptr<UEnumeration, void (*)(UEnumeration*)> all(ucal_openTimeZones(&status), uenum_close);
        if (U_FAILURE(status) || !all) {
            return out;
        }
        int32_t length = 0;
        while (const char* name = uenum_next(all.get(), &length, &status)) {
            if (U_FAILURE(status)) {
                break;
            }
            const std::string id(name, size_t(length));
            if (id != "Etc/Unknown") {
                out.emplace(lowered(id), id);
            }
        }
        return out;
    }();
    return zones;
}

/// ECMA-402 IsValidTimeZoneName then CanonicalizeTimeZoneName: ICU's canonical (CLDR) id, the UTC aliases as "UTC".
std::optional<std::string> canonicalTimeZone(std::string_view name) {
    const auto& zones = timeZonesByName();
    auto found = zones.find(lowered(name));
    if (found == zones.end()) {
        return std::nullopt;
    }
    std::u16string id(found->second.begin(), found->second.end());
    char16_t out[65] = {};
    UBool isSystem = false;
    UErrorCode status = U_ZERO_ERROR;
    const int32_t length = ucal_getCanonicalTimeZoneID(id.data(), int32_t(id.size()), out, 64, &isSystem, &status);
    if (U_FAILURE(status) || status == U_STRING_NOT_TERMINATED_WARNING || !isSystem || length <= 0) {
        return std::nullopt;
    }
    std::string canonical;
    for (int32_t i = 0; i < length; i++) {
        canonical += char(out[i]);
    }
    if (canonical == "Etc/UTC" || canonical == "Etc/GMT" || canonical == "GMT" || canonical == "UTC") {
        return std::string("UTC");
    }
    return canonical;
}

std::string icuCalendarName(const std::string& bcp47) {
    if (bcp47 == "gregory") {
        return "gregorian";
    }
    if (bcp47 == "ethioaa") {
        return "ethiopic-amete-alem";
    }
    if (bcp47 == "islamicc") {
        return "islamic-civil";
    }
    return bcp47;
}

std::string bcp47CalendarName(const std::string& icu) {
    if (icu == "gregorian") {
        return "gregory";
    }
    if (icu == "ethiopic-amete-alem") {
        return "ethioaa";
    }
    return icu;
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

void closeGenerator(UDateTimePatternGenerator* g) {
    udatpg_close(g);
}
void closeFormat(UDateFormat* f) {
    udat_close(f);
}

UDateTimePatternGenerator* generatorFor(JSContext* ctx, const char* icuLocale) {
    UDateTimePatternGenerator* g = intlState(ctx).cache.get<UDateTimePatternGenerator>(
        ctx, std::string("dtpg\x1f") + icuLocale,
        [&]() -> UDateTimePatternGenerator* {
            UErrorCode status = U_ZERO_ERROR;
            UDateTimePatternGenerator* made = udatpg_open(icuLocale, &status);
            if (U_FAILURE(status)) {
                if (made) {
                    udatpg_close(made);
                }
                return nullptr;
            }
            return made;
        },
        closeGenerator);
    if (!g) {
        throw RangeError{"Intl.DateTimeFormat: ICU refused the locale."};
    }
    return g;
}

UDateFormat* formatFor(JSContext* ctx, const DateTimeFormatRecord& r) {
    char16_t zone[65];
    const std::u16string_view z = r.zone16(zone);
    std::string key = std::string("dtf\x1f") + r.icuLocale + "\x1f" + r.timeZone + "\x1f";
    key.append(reinterpret_cast<const char*>(r.pattern), size_t(r.patternLength) * 2);
    UDateFormat* f = intlState(ctx).cache.get<UDateFormat>(
        ctx, key,
        [&]() -> UDateFormat* {
            UErrorCode status = U_ZERO_ERROR;
            UDateFormat* made = udat_open(UDAT_PATTERN, UDAT_PATTERN, r.icuLocale, z.data(), int32_t(z.size()), r.pattern,
                                          r.patternLength, &status);
            if (U_FAILURE(status)) {
                if (made) {
                    udat_close(made);
                }
                return nullptr;
            }
            return made;
        },
        closeFormat);
    if (!f) {
        throw RangeError{"Intl.DateTimeFormat: ICU refused the format."};
    }
    return f;
}

void setPattern(DateTimeFormatRecord& r, const Text16& pattern) {
    if (pattern.size() > size_t(kMaxPattern)) {
        throw RangeError{"Intl.DateTimeFormat: the pattern is too long."};
    }
    std::copy(pattern.begin(), pattern.end(), r.pattern);
    r.patternLength = int32_t(pattern.size());
}

Text16 bestPattern(JSContext* ctx, UDateTimePatternGenerator* g, const std::u16string& skeleton) {
    return icuText(ctx, [&](char16_t* buffer, int32_t capacity, UErrorCode* status) {
        return udatpg_getBestPatternWithOptions(g, skeleton.data(), int32_t(skeleton.size()), UDATPG_MATCH_HOUR_FIELD_LENGTH,
                                                buffer, capacity, status);
    });
}

/// `pattern` with every hour field's letter (outside quoted literals) replaced by `letter`: ICU's generator answers a
/// skeleton's 12- or 24-hour choice with the locale's own letter for it (h for K in en-US).
Text16 withHourLetter(Text16 pattern, char16_t letter) {
    if (letter == u'j') {
        return pattern;
    }
    bool quoted = false;
    for (char16_t& c : pattern) {
        if (c == u'\'') {
            quoted = !quoted;
        } else if (!quoted && (c == u'h' || c == u'H' || c == u'K' || c == u'k')) {
            c = letter;
        }
    }
    return pattern;
}

/// `pattern` with its era field (outside quoted literals) at the requested width (`letters`: G, GGGG or GGGGG): Apple's
/// CLDR data answers a short era with a narrow one ("1/1/1970 A"), where ECMA-402 asks for the requested representation
/// and V8 gives "AD" (widget-sandbox v0.1.1's Intl fixture).
Text16 withEraWidth(const Text16& pattern, std::u16string_view letters) {
    // On the runtime's allocator, as the generator's answer is.
    Text16 out(pattern.get_allocator());
    bool quoted = false;
    for (size_t i = 0; i < pattern.size();) {
        const char16_t c = pattern[i];
        if (c == u'\'') {
            quoted = !quoted;
        }
        if (quoted || c != u'G') {
            out.push_back(c);
            i++;
            continue;
        }
        while (i < pattern.size() && pattern[i] == u'G') {
            i++;
        }
        out.insert(out.end(), letters.begin(), letters.end());
    }
    return out;
}

/// The runs of pattern letters outside quoted literals: (letter, count).
template <class F>
void eachPatternField(std::u16string_view pattern, F f) {
    bool quoted = false;
    for (size_t i = 0; i < pattern.size();) {
        const char16_t c = pattern[i];
        if (c == u'\'') {
            quoted = !quoted;
            i++;
            continue;
        }
        if (quoted || !((c >= u'a' && c <= u'z') || (c >= u'A' && c <= u'Z'))) {
            i++;
            continue;
        }
        size_t j = i;
        while (j < pattern.size() && pattern[j] == c) {
            j++;
        }
        f(char(c), int(j - i));
        i = j;
    }
}

int8_t textual(int count) {
    return count == 5 ? 0 : count == 4 ? 2 : 1;  // narrow, long, short
}

/// What the pattern formats: ECMA-402's resolved fields and hour cycle.
void readPatternFields(DateTimeFormatRecord& r, bool withComponents) {
    const std::u16string_view pattern(r.pattern, size_t(r.patternLength));
    eachPatternField(pattern, [&](char letter, int count) {
        auto set = [&](Component c, int8_t value) {
            if (withComponents) {
                r.components[c] = value;
            }
        };
        switch (letter) {
        case 'G':
            set(Era, textual(count));
            break;
        case 'y':
        case 'Y':
        case 'u':
        case 'U':
        case 'r':
            set(Year, count == 2 ? 0 : 1);
            break;
        case 'M':
        case 'L':
            set(Month, count == 1 ? 1 : count == 2 ? 0 : count == 3 ? 3 : count == 4 ? 4 : 2);
            break;
        case 'd':
            set(Day, count == 2 ? 0 : 1);
            break;
        case 'E':
        case 'c':
        case 'e':
            set(Weekday, textual(count));
            break;
        case 'B':
            set(DayPeriod, textual(count));
            break;
        case 'K':
        case 'h':
        case 'H':
        case 'k':
            r.hourCycle = int8_t(letter == 'K' ? 0 : letter == 'h' ? 1 : letter == 'H' ? 2 : 3);
            set(Hour, count == 2 ? 0 : 1);
            break;
        case 'm':
            set(Minute, count == 2 ? 0 : 1);
            break;
        case 's':
            set(Second, count == 2 ? 0 : 1);
            break;
        case 'S':
            set(FractionalSecondDigits, int8_t(std::min(count, 3)));
            break;
        case 'z':
            set(TimeZoneName, count == 4 ? 1 : 0);
            break;
        case 'O':
            set(TimeZoneName, count == 4 ? 3 : 2);
            break;
        case 'v':
            set(TimeZoneName, count == 4 ? 5 : 4);
            break;
        case 'V':
        case 'Z':
        case 'X':
        case 'x':
            set(TimeZoneName, 0);
            break;
        default:
            break;
        }
    });
}

/// ECMA-402 CreateDateTimeFormat (2024 edition), without the object: every option in its order, then the pattern.
DateTimeFormatRecord createDateTimeFormat(JSContext* ctx, JSValueConst locales, JSValueConst options, DateDefaults which) {
    DateTimeFormatRecord r;
    const std::vector<std::string> requested = canonicalizeLocaleList(ctx, locales);
    Value object = coerceOptionsToObject(ctx, options);
    JSValueConst o = object.get();
    getStringOption(ctx, o, "localeMatcher", {"lookup", "best fit"});
    std::optional<std::string> calendar = getStringOption(ctx, o, "calendar", {});
    if (calendar && !isUnicodeType(*calendar)) {
        throw RangeError{"Intl: the value of calendar is out of range."};
    }
    std::optional<std::string> numberingSystem = getStringOption(ctx, o, "numberingSystem", {});
    if (numberingSystem && !isUnicodeType(*numberingSystem)) {
        throw RangeError{"Intl: the value of numberingSystem is out of range."};
    }
    const std::optional<bool> hour12 = getBooleanOption(ctx, o, "hour12");
    std::optional<std::string> hourCycleOption = getStringOption(ctx, o, "hourCycle", kHourCycles);
    if (hour12) {
        hourCycleOption.reset();
    }
    const std::string locale = resolveLocale(ctx, requested);
    copyInto(r.locale, locale);
    copyInto(r.icuLocale, toICULocale(locale));
    if (calendar) {
        withKeyword(r.icuLocale, "calendar", icuCalendarName(lowered(*calendar)));
    }
    if (numberingSystem && isSupportedNumberingSystem(lowered(*numberingSystem))) {
        withKeyword(r.icuLocale, "numbers", lowered(*numberingSystem));
    }
    std::optional<std::string> zoneOption = getStringOption(ctx, o, "timeZone", {});
    std::optional<std::string> zone;
    if (zoneOption) {
        zone = canonicalTimeZone(*zoneOption);
        if (!zone) {
            throw RangeError{"Intl.DateTimeFormat: invalid time zone."};
        }
    } else {
        zone = canonicalTimeZone(Runtime::from(ctx).host().defaultTimeZone());
    }
    copyInto(r.timeZone, zone.value_or("UTC"));
    int8_t requestedComponents[ComponentCount];
    bool hasExplicitComponents = false;
    for (uint8_t c = 0; c < ComponentCount; c++) {
        if (c == FractionalSecondDigits) {
            std::optional<int> digits = getNumberOption(ctx, o, "fractionalSecondDigits", 1, 3);
            requestedComponents[c] = digits ? int8_t(*digits) : int8_t(-1);
        } else {
            const std::initializer_list<const char*> allowed = allowedFor(Component(c));
            requestedComponents[c] = int8_t(optionIndex(getStringOption(ctx, o, kComponentNames[c], allowed), allowed, -1));
        }
        hasExplicitComponents = hasExplicitComponents || requestedComponents[c] >= 0;
    }
    getStringOption(ctx, o, "formatMatcher", {"basic", "best fit"});
    r.dateStyle = int8_t(optionIndex(getStringOption(ctx, o, "dateStyle", kStyles), kStyles, -1));
    r.timeStyle = int8_t(optionIndex(getStringOption(ctx, o, "timeStyle", kStyles), kStyles, -1));
    // Every option is read: from here on nothing runs script, and ICU may be opened.
    UDateTimePatternGenerator* generator = generatorFor(ctx, r.icuLocale);
    UErrorCode status = U_ZERO_ERROR;
    const UDateFormatHourCycle localeCycle = udatpg_getDefaultHourCycle(generator, &status);
    char16_t hourLetter = u'j';
    if (hour12) {
        hourLetter = *hour12 ? (localeCycle == UDAT_HOUR_CYCLE_11 ? u'K' : u'h') : (localeCycle == UDAT_HOUR_CYCLE_24 ? u'k' : u'H');
    } else if (hourCycleOption) {
        const char16_t letters[] = {u'K', u'h', u'H', u'k'};
        hourLetter = letters[optionIndex(hourCycleOption, kHourCycles, 1)];
    }
    if (r.dateStyle >= 0 || r.timeStyle >= 0) {
        if (hasExplicitComponents) {
            throw TypeError{"Intl.DateTimeFormat: dateStyle and timeStyle cannot be combined with date-time components."};
        }
        if ((which == DateDefaults::Date && r.timeStyle >= 0) || (which == DateDefaults::Time && r.dateStyle >= 0)) {
            throw TypeError{"Intl.DateTimeFormat: this method does not take that style."};
        }
        char16_t zone16[65];
        const std::u16string_view z = r.zone16(zone16);
        status = U_ZERO_ERROR;
        std::unique_ptr<UDateFormat, void (*)(UDateFormat*)> styled(
            udat_open(r.timeStyle >= 0 ? UDateFormatStyle(r.timeStyle) : UDAT_NONE,
                      r.dateStyle >= 0 ? UDateFormatStyle(r.dateStyle) : UDAT_NONE, r.icuLocale, z.data(), int32_t(z.size()),
                      nullptr, -1, &status),
            udat_close);
        if (U_FAILURE(status) || !styled) {
            throw RangeError{"Intl.DateTimeFormat: ICU refused the style."};
        }
        charge(ctx, work::kIntlOpen);
        Text16 pattern = icuText(ctx, [&](char16_t* buffer, int32_t capacity, UErrorCode* st) {
            return udat_toPattern(styled.get(), false, buffer, capacity, st);
        });
        if (r.timeStyle >= 0 && hourLetter != u'j') {
            // An hour cycle with a time style: the style's skeleton with its hour letter replaced, through the generator.
            Text16 skeleton = icuText(ctx, [&](char16_t* buffer, int32_t capacity, UErrorCode* st) {
                return udatpg_getSkeleton(nullptr, pattern.data(), int32_t(pattern.size()), buffer, capacity, st);
            });
            std::u16string adjusted;
            const bool twentyFour = hourLetter == u'H' || hourLetter == u'k';
            for (char16_t c : skeleton) {
                if (c == u'h' || c == u'H' || c == u'K' || c == u'k' || c == u'j') {
                    adjusted += hourLetter;
                } else if (!(twentyFour && (c == u'a' || c == u'b' || c == u'B'))) {
                    adjusted += c;
                }
            }
            pattern = withHourLetter(bestPattern(ctx, generator, adjusted), hourLetter);
        }
        setPattern(r, pattern);
        readPatternFields(r, false);
    } else {
        const bool requiresAny = which == DateDefaults::Any || which == DateDefaults::Constructor;
        bool needDefaults = true;
        if (which == DateDefaults::Date || requiresAny) {
            for (Component c : {Weekday, Year, Month, Day}) {
                needDefaults = needDefaults && requestedComponents[c] < 0;
            }
        }
        if (which == DateDefaults::Time || requiresAny) {
            for (Component c : {DayPeriod, Hour, Minute, Second, FractionalSecondDigits}) {
                needDefaults = needDefaults && requestedComponents[c] < 0;
            }
        }
        if (needDefaults && (which == DateDefaults::Date || which == DateDefaults::Any || which == DateDefaults::Constructor)) {
            requestedComponents[Year] = requestedComponents[Month] = requestedComponents[Day] = 1;  // numeric
        }
        if (needDefaults && (which == DateDefaults::Time || which == DateDefaults::Any)) {
            requestedComponents[Hour] = requestedComponents[Minute] = requestedComponents[Second] = 1;
        }
        std::u16string skeleton;
        auto add = [&](const char* text) {
            for (const char* p = text; *p; p++) {
                skeleton += char16_t(*p);
            }
        };
        const int8_t* c = requestedComponents;
        const char* const textualLetters[3][3] = {{"EEEEE", "EEE", "EEEE"}, {"GGGGG", "G", "GGGG"}, {"BBBBB", "B", "BBBB"}};
        if (c[Weekday] >= 0) add(textualLetters[0][c[Weekday]]);
        if (c[Era] >= 0) add(textualLetters[1][c[Era]]);
        if (c[Year] >= 0) add(c[Year] == 0 ? "yy" : "y");
        const char* const monthLetters[] = {"MM", "M", "MMMMM", "MMM", "MMMM"};
        const char* const zoneLetters[] = {"z", "zzzz", "O", "OOOO", "v", "vvvv"};
        if (c[Month] >= 0) add(monthLetters[c[Month]]);
        if (c[Day] >= 0) add(c[Day] == 0 ? "dd" : "d");
        if (c[DayPeriod] >= 0) add(textualLetters[2][c[DayPeriod]]);
        if (c[Hour] >= 0) {
            skeleton += hourLetter;
            if (c[Hour] == 0) {
                skeleton += hourLetter;
            }
        }
        if (c[Minute] >= 0) add(c[Minute] == 0 ? "mm" : "m");
        if (c[Second] >= 0) add(c[Second] == 0 ? "ss" : "s");
        if (c[FractionalSecondDigits] > 0) skeleton += std::u16string(size_t(c[FractionalSecondDigits]), u'S');
        if (c[TimeZoneName] >= 0) add(zoneLetters[c[TimeZoneName]]);
        Text16 pattern = withHourLetter(bestPattern(ctx, generator, skeleton), hourLetter);
        if (c[Era] >= 0) {
            const std::string_view era = textualLetters[1][c[Era]];
            pattern = withEraWidth(pattern, std::u16string(era.begin(), era.end()));
        }
        setPattern(r, pattern);
        readPatternFields(r, true);
    }
    // The calendar and numbering system ICU uses for this locale.
    UDateFormat* f = formatFor(ctx, r);
    status = U_ZERO_ERROR;
    const char* calendarType = ucal_getType(udat_getCalendar(f), &status);
    copyInto(r.calendar, U_SUCCESS(status) && calendarType ? bcp47CalendarName(calendarType) : std::string("gregory"));
    status = U_ZERO_ERROR;
    std::unique_ptr<UNumberingSystem, void (*)(UNumberingSystem*)> numbering(unumsys_open(r.icuLocale, &status), unumsys_close);
    copyInto(r.numberingSystem, U_SUCCESS(status) && numbering ? std::string(unumsys_getName(numbering.get())) : std::string("latn"));
    return r;
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

JSValue formatDateTime(JSContext* ctx, const DateTimeFormatRecord& r, double x) {
    const double t = clippedTime(x);
    UDateFormat* f = formatFor(ctx, r);
    return icuString(ctx, [&](char16_t* buffer, int32_t capacity, UErrorCode* status) {
        return udat_format(f, t, buffer, capacity, nullptr, status);
    });
}

const char* datePartType(int field, std::u16string_view, const void*) {
    switch (field) {
    case UDAT_ERA_FIELD:
        return "era";
    case UDAT_YEAR_FIELD:
    case UDAT_EXTENDED_YEAR_FIELD:
    case UDAT_YEAR_WOY_FIELD:
        return "year";
    case UDAT_YEAR_NAME_FIELD:
        return "yearName";
    case UDAT_RELATED_YEAR_FIELD:
        return "relatedYear";
    case UDAT_MONTH_FIELD:
    case UDAT_STANDALONE_MONTH_FIELD:
        return "month";
    case UDAT_DATE_FIELD:
        return "day";
    case UDAT_HOUR_OF_DAY1_FIELD:
    case UDAT_HOUR_OF_DAY0_FIELD:
    case UDAT_HOUR1_FIELD:
    case UDAT_HOUR0_FIELD:
        return "hour";
    case UDAT_MINUTE_FIELD:
        return "minute";
    case UDAT_SECOND_FIELD:
        return "second";
    case UDAT_FRACTIONAL_SECOND_FIELD:
        return "fractionalSecond";
    case UDAT_DAY_OF_WEEK_FIELD:
    case UDAT_STANDALONE_DAY_FIELD:
    case UDAT_DOW_LOCAL_FIELD:
        return "weekday";
    case UDAT_AM_PM_FIELD:
    case UDAT_AM_PM_MIDNIGHT_NOON_FIELD:
    case UDAT_FLEXIBLE_DAY_PERIOD_FIELD:
        return "dayPeriod";
    case UDAT_TIMEZONE_FIELD:
    case UDAT_TIMEZONE_RFC_FIELD:
    case UDAT_TIMEZONE_GENERIC_FIELD:
    case UDAT_TIMEZONE_SPECIAL_FIELD:
    case UDAT_TIMEZONE_LOCALIZED_GMT_OFFSET_FIELD:
    case UDAT_TIMEZONE_ISO_FIELD:
    case UDAT_TIMEZONE_ISO_LOCAL_FIELD:
        return "timeZoneName";
    default:
        return "literal";
    }
}

JSValue formatDateTimeToParts(JSContext* ctx, const DateTimeFormatRecord& r, double x) {
    const double t = clippedTime(x);
    UDateFormat* f = formatFor(ctx, r);
    FieldIterator fields = openFieldIterator();
    const Text16 text = icuText(ctx, [&](char16_t* buffer, int32_t capacity, UErrorCode* status) {
        return udat_formatForFields(f, t, buffer, capacity, fields.get(), status);
    });
    return partsFromFields(ctx, text, fields.get(), datePartType, nullptr);
}

JSClassID dateTimeFormatClass(JSContext* ctx) {
    return intlState(ctx).classIds[size_t(IntlClass::DateTimeFormat)];
}

JSValue boundFormat(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv, int, JSValueConst* data) {
    return glue(ctx, [&]() -> JSValue {
        DateTimeFormatObject& dtf = intlReceiver<DateTimeFormatObject>(ctx, data[0], dateTimeFormatClass(ctx), "format");
        const double x = timeOf(ctx, argc > 0 ? argv[0] : JS_UNDEFINED);
        return formatDateTime(ctx, dtf.record, x);
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
        const double x = timeOf(ctx, argc > 0 ? argv[0] : JS_UNDEFINED);
        return formatDateTimeToParts(ctx, dtf.record, x);
    });
}

void defineString(JSContext* ctx, JSValueConst object, const char* name, std::string_view value) {
    check(ctx, JS_DefinePropertyValueStr(ctx, object, name, JS_NewStringLen(ctx, value.data(), value.size()), JS_PROP_C_W_E));
}

const char* at(std::initializer_list<const char*> list, size_t index) {
    return *(list.begin() + std::ptrdiff_t(index));
}

JSValue resolvedOptions(JSContext* ctx, JSValueConst thisVal, int, JSValueConst*) {
    return glue(ctx, [&]() -> JSValue {
        const DateTimeFormatRecord& r = intlReceiver<DateTimeFormatObject>(ctx, thisVal, dateTimeFormatClass(ctx),
                                                                           "Intl.DateTimeFormat.prototype.resolvedOptions")
                                            .record;
        Value o = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
        defineString(ctx, o.get(), "locale", r.locale);
        defineString(ctx, o.get(), "calendar", r.calendar);
        defineString(ctx, o.get(), "numberingSystem", r.numberingSystem);
        defineString(ctx, o.get(), "timeZone", r.timeZone);
        if (r.hourCycle >= 0) {
            defineString(ctx, o.get(), "hourCycle", at(kHourCycles, size_t(r.hourCycle)));
            check(ctx, JS_DefinePropertyValueStr(ctx, o.get(), "hour12", JS_NewBool(ctx, r.hourCycle <= 1), JS_PROP_C_W_E));
        }
        for (uint8_t c = 0; c < ComponentCount; c++) {
            if (r.components[c] < 0) {
                continue;
            }
            if (c == FractionalSecondDigits) {
                check(ctx, JS_DefinePropertyValueStr(ctx, o.get(), kComponentNames[c], JS_NewInt32(ctx, r.components[c]), JS_PROP_C_W_E));
            } else {
                defineString(ctx, o.get(), kComponentNames[c], at(allowedFor(Component(c)), size_t(r.components[c])));
            }
        }
        if (r.dateStyle >= 0) {
            defineString(ctx, o.get(), "dateStyle", at(kStyles, size_t(r.dateStyle)));
        }
        if (r.timeStyle >= 0) {
            defineString(ctx, o.get(), "timeStyle", at(kStyles, size_t(r.timeStyle)));
        }
        return o.release();
    });
}

JSValue construct(JSContext* ctx, JSValueConst newTarget, int argc, JSValueConst* argv) {
    return glue(ctx, [&]() -> JSValue {
        const JSClassID id = dateTimeFormatClass(ctx);
        Value proto = prototypeFromConstructor(ctx, newTarget, id);
        const DateTimeFormatRecord record = createDateTimeFormat(ctx, argc > 0 ? argv[0] : JS_UNDEFINED,
                                                                 argc > 1 ? argv[1] : JS_UNDEFINED, DateDefaults::Constructor);
        return createIntlObject<DateTimeFormatObject>(ctx, proto.get(), id, record).release();
    });
}

const JSCFunctionListEntry kPrototype[] = {
    JS_CGETSET_DEF("format", getFormat, nullptr),
    JS_CFUNC_DEF("formatToParts", 1, formatToParts),
    JS_CFUNC_DEF("resolvedOptions", 0, resolvedOptions),
    JS_PROP_STRING_DEF("[Symbol.toStringTag]", "Intl.DateTimeFormat", JS_PROP_CONFIGURABLE),
};

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
    const DateTimeFormatRecord record = createDateTimeFormat(ctx, locales, options, which);
    return formatDateTime(ctx, record, timeValue);
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
    const char* const names[] = {"toLocaleString", "toLocaleDateString", "toLocaleTimeString"};
    for (int i = 0; i < 3; i++) {
        JSValue function = checked(ctx, JS_NewCFunctionMagic(ctx, toLocale, names[i], 0, JS_CFUNC_generic_magic, i));
        check(ctx, JS_DefinePropertyValueStr(ctx, proto.get(), names[i], function, JS_PROP_WRITABLE | JS_PROP_CONFIGURABLE));
    }
}

} // namespace wr::intl
