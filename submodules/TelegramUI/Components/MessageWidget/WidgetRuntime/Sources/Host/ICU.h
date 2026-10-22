// The system ICU, libicucore (V5b plan, Task 1). The SDK ships only a few of ICU's headers (utypes.h, uidna.h, uchar.h,
// ustring.h, …), so this file declares the rest of what the runtime calls, copied by hand from ICU 78.1's headers.
//
// The floor is ICU 69, iOS 15.0's: everything declared here is marked `@stable ICU` 69 or older in those headers, and
// the number skeletons the runtime builds use only syntax ICU 69 parses. Apple's library exports the names without
// ICU's version suffix, which is what U_DISABLE_RENAMING selects; it must come before any ICU header.
#pragma once

#ifndef U_DISABLE_RENAMING
#define U_DISABLE_RENAMING 1
#endif
static_assert(U_DISABLE_RENAMING == 1, "libicucore exports unsuffixed names");
// Apple's headers make UChar uint16_t; ICU's own default in C++ is char16_t, the same 16-bit unit, which the runtime's
// UTF-16 buffers (Text16) hold.
#ifndef UCHAR_TYPE
#define UCHAR_TYPE char16_t
#endif

#include <unicode/parseerr.h>
#include <unicode/uchar.h>
#include <unicode/uidna.h>
#include <unicode/ustring.h>
#include <unicode/utypes.h>

static_assert(U_ICU_VERSION_MAJOR_NUM >= 69, "the floor is ICU 69 (iOS 15.0)");

// Every function declared here is a weak import: the app links against the newest SDK's libicucore, and a symbol an
// older iOS lacked would otherwise stop the whole app from launching there. Intl installs itself only when all of them
// are present (wr::intl::icuAvailable); the SDK's own headers (u_errorName, uidna_*) declare ICU 4.6-era functions.
#define WR_ICU_WEAK __attribute__((weak_import))

// uloc.h
#define ULOC_FULLNAME_CAPACITY 157

U_CAPI int32_t U_EXPORT2 uloc_forLanguageTag(const char* langtag, char* localeID, int32_t localeIDCapacity,
                                             int32_t* parsedLength, UErrorCode* err) WR_ICU_WEAK;
U_CAPI int32_t U_EXPORT2 uloc_toLanguageTag(const char* localeID, char* langtag, int32_t langtagCapacity, UBool strict,
                                            UErrorCode* err) WR_ICU_WEAK;
// uloc_openAvailableByType: ICU 65. The legacy aliases (zh_TW, zh_HK, …) are available locales too.
enum ULocAvailableType { ULOC_AVAILABLE_DEFAULT, ULOC_AVAILABLE_ONLY_LEGACY_ALIASES, ULOC_AVAILABLE_WITH_LEGACY_ALIASES };
typedef struct UEnumeration UEnumeration;
U_CAPI UEnumeration* U_EXPORT2 uloc_openAvailableByType(ULocAvailableType type, UErrorCode* status) WR_ICU_WEAK;

// ubidi.h (fidelity plan, Task 13: WidgetContainer::bidi_levels). Not Intl's: icuAvailable() leaves them out, and the
// container checks them itself, keeping the logical order on an ICU without them.
typedef struct UBiDi UBiDi;
typedef uint8_t UBiDiLevel;
U_CAPI UBiDi* U_EXPORT2 ubidi_open(void) WR_ICU_WEAK;
U_CAPI void U_EXPORT2 ubidi_close(UBiDi* pBiDi) WR_ICU_WEAK;
U_CAPI void U_EXPORT2 ubidi_setPara(UBiDi* pBiDi, const UChar* text, int32_t length, UBiDiLevel paraLevel,
                                    UBiDiLevel* embeddingLevels, UErrorCode* pErrorCode) WR_ICU_WEAK;
U_CAPI UBiDiLevel U_EXPORT2 ubidi_getLevelAt(const UBiDi* pBiDi, int32_t charIndex) WR_ICU_WEAK;

// umisc.h, ufieldpositer.h
typedef struct UFieldPositionIterator UFieldPositionIterator;
U_CAPI UFieldPositionIterator* U_EXPORT2 ufieldpositer_open(UErrorCode* status) WR_ICU_WEAK;
U_CAPI void U_EXPORT2 ufieldpositer_close(UFieldPositionIterator* fpositer) WR_ICU_WEAK;
U_CAPI int32_t U_EXPORT2 ufieldpositer_next(UFieldPositionIterator* fpositer, int32_t* beginIndex, int32_t* endIndex) WR_ICU_WEAK;

// unum.h: UNumberFormatFields
enum UNumberFormatFields {
    UNUM_INTEGER_FIELD,
    UNUM_FRACTION_FIELD,
    UNUM_DECIMAL_SEPARATOR_FIELD,
    UNUM_EXPONENT_SYMBOL_FIELD,
    UNUM_EXPONENT_SIGN_FIELD,
    UNUM_EXPONENT_FIELD,
    UNUM_GROUPING_SEPARATOR_FIELD,
    UNUM_CURRENCY_FIELD,
    UNUM_PERCENT_FIELD,
    UNUM_PERMILL_FIELD,
    UNUM_SIGN_FIELD,
    UNUM_MEASURE_UNIT_FIELD,
    UNUM_COMPACT_FIELD,
    UNUM_APPROXIMATELY_SIGN_FIELD,  // ICU 71; ICU 69 and 70 report the approximately sign as UNUM_SIGN_FIELD
};

// unumberformatter.h, uformattednumber.h (ICU 62)
typedef struct UNumberFormatter UNumberFormatter;
typedef struct UFormattedNumber UFormattedNumber;
U_CAPI UNumberFormatter* U_EXPORT2 unumf_openForSkeletonAndLocale(const UChar* skeleton, int32_t skeletonLen,
                                                                  const char* locale, UErrorCode* ec) WR_ICU_WEAK;
U_CAPI void U_EXPORT2 unumf_close(UNumberFormatter* uformatter) WR_ICU_WEAK;
U_CAPI UFormattedNumber* U_EXPORT2 unumf_openResult(UErrorCode* ec) WR_ICU_WEAK;
U_CAPI void U_EXPORT2 unumf_closeResult(UFormattedNumber* uresult) WR_ICU_WEAK;
U_CAPI void U_EXPORT2 unumf_formatDouble(const UNumberFormatter* uformatter, double value, UFormattedNumber* uresult,
                                         UErrorCode* ec) WR_ICU_WEAK;
U_CAPI void U_EXPORT2 unumf_formatDecimal(const UNumberFormatter* uformatter, const char* value, int32_t valueLen,
                                          UFormattedNumber* uresult, UErrorCode* ec) WR_ICU_WEAK;
U_CAPI int32_t U_EXPORT2 unumf_resultToString(const UFormattedNumber* uresult, UChar* buffer, int32_t bufferCapacity,
                                              UErrorCode* ec) WR_ICU_WEAK;
U_CAPI void U_EXPORT2 unumf_resultGetAllFieldPositions(const UFormattedNumber* uresult,
                                                       UFieldPositionIterator* ufpositer, UErrorCode* ec) WR_ICU_WEAK;

// ucurr.h
U_CAPI int32_t U_EXPORT2 ucurr_getDefaultFractionDigits(const UChar* currency, UErrorCode* ec) WR_ICU_WEAK;

// unumsys.h
typedef struct UNumberingSystem UNumberingSystem;
U_CAPI UNumberingSystem* U_EXPORT2 unumsys_open(const char* locale, UErrorCode* status) WR_ICU_WEAK;
U_CAPI UNumberingSystem* U_EXPORT2 unumsys_openByName(const char* name, UErrorCode* status) WR_ICU_WEAK;
U_CAPI void U_EXPORT2 unumsys_close(UNumberingSystem* unumsys) WR_ICU_WEAK;
U_CAPI const char* U_EXPORT2 unumsys_getName(const UNumberingSystem* unumsys) WR_ICU_WEAK;
U_CAPI UBool U_EXPORT2 unumsys_isAlgorithmic(const UNumberingSystem* unumsys) WR_ICU_WEAK;

// uloc.h (keywords), uenum.h
U_CAPI int32_t U_EXPORT2 uloc_setKeywordValue(const char* keywordName, const char* keywordValue, char* buffer,
                                              int32_t bufferCapacity, UErrorCode* status) WR_ICU_WEAK;
U_CAPI void U_EXPORT2 uenum_close(UEnumeration* en) WR_ICU_WEAK;
U_CAPI const char* U_EXPORT2 uenum_next(UEnumeration* en, int32_t* resultLength, UErrorCode* status) WR_ICU_WEAK;

// ucal.h
typedef void* UCalendar;
U_CAPI UEnumeration* U_EXPORT2 ucal_openTimeZones(UErrorCode* ec) WR_ICU_WEAK;
U_CAPI int32_t U_EXPORT2 ucal_getCanonicalTimeZoneID(const UChar* id, int32_t len, UChar* result, int32_t resultCapacity,
                                                     UBool* isSystemID, UErrorCode* status) WR_ICU_WEAK;
U_CAPI const char* U_EXPORT2 ucal_getType(const UCalendar* cal, UErrorCode* status) WR_ICU_WEAK;

// udat.h
typedef void* UDateFormat;
enum UDateFormatStyle { UDAT_FULL, UDAT_LONG, UDAT_MEDIUM, UDAT_SHORT, UDAT_NONE = -1, UDAT_PATTERN = -2 };
enum UDateFormatField {
    UDAT_ERA_FIELD = 0,
    UDAT_YEAR_FIELD = 1,
    UDAT_MONTH_FIELD = 2,
    UDAT_DATE_FIELD = 3,
    UDAT_HOUR_OF_DAY1_FIELD = 4,
    UDAT_HOUR_OF_DAY0_FIELD = 5,
    UDAT_MINUTE_FIELD = 6,
    UDAT_SECOND_FIELD = 7,
    UDAT_FRACTIONAL_SECOND_FIELD = 8,
    UDAT_DAY_OF_WEEK_FIELD = 9,
    UDAT_AM_PM_FIELD = 14,
    UDAT_HOUR1_FIELD = 15,
    UDAT_HOUR0_FIELD = 16,
    UDAT_TIMEZONE_FIELD = 17,
    UDAT_YEAR_WOY_FIELD = 18,
    UDAT_DOW_LOCAL_FIELD = 19,
    UDAT_EXTENDED_YEAR_FIELD = 20,
    UDAT_TIMEZONE_RFC_FIELD = 23,
    UDAT_TIMEZONE_GENERIC_FIELD = 24,
    UDAT_STANDALONE_DAY_FIELD = 25,
    UDAT_STANDALONE_MONTH_FIELD = 26,
    UDAT_TIMEZONE_SPECIAL_FIELD = 29,
    UDAT_YEAR_NAME_FIELD = 30,
    UDAT_TIMEZONE_LOCALIZED_GMT_OFFSET_FIELD = 31,
    UDAT_TIMEZONE_ISO_FIELD = 32,
    UDAT_TIMEZONE_ISO_LOCAL_FIELD = 33,
    UDAT_RELATED_YEAR_FIELD = 34,
    UDAT_AM_PM_MIDNIGHT_NOON_FIELD = 35,
    UDAT_FLEXIBLE_DAY_PERIOD_FIELD = 36,
};
enum UDateFormatHourCycle { UDAT_HOUR_CYCLE_11, UDAT_HOUR_CYCLE_12, UDAT_HOUR_CYCLE_23, UDAT_HOUR_CYCLE_24 };
U_CAPI UDateFormat* U_EXPORT2 udat_open(UDateFormatStyle timeStyle, UDateFormatStyle dateStyle, const char* locale,
                                        const UChar* tzID, int32_t tzIDLength, const UChar* pattern,
                                        int32_t patternLength, UErrorCode* status) WR_ICU_WEAK;
U_CAPI void U_EXPORT2 udat_close(UDateFormat* format) WR_ICU_WEAK;
U_CAPI int32_t U_EXPORT2 udat_format(const UDateFormat* format, UDate dateToFormat, UChar* result, int32_t resultLength,
                                     void* position, UErrorCode* status) WR_ICU_WEAK;
U_CAPI int32_t U_EXPORT2 udat_formatForFields(const UDateFormat* format, UDate dateToFormat, UChar* result,
                                              int32_t resultLength, UFieldPositionIterator* fpositer, UErrorCode* status) WR_ICU_WEAK;
U_CAPI int32_t U_EXPORT2 udat_toPattern(const UDateFormat* fmt, UBool localized, UChar* result, int32_t resultLength,
                                        UErrorCode* status) WR_ICU_WEAK;
U_CAPI const UCalendar* U_EXPORT2 udat_getCalendar(const UDateFormat* fmt) WR_ICU_WEAK;

// udatpg.h
typedef void* UDateTimePatternGenerator;
enum UDateTimePatternMatchOptions { UDATPG_MATCH_NO_OPTIONS = 0, UDATPG_MATCH_HOUR_FIELD_LENGTH = 1 << 11 };
U_CAPI UDateTimePatternGenerator* U_EXPORT2 udatpg_open(const char* locale, UErrorCode* pErrorCode) WR_ICU_WEAK;
U_CAPI void U_EXPORT2 udatpg_close(UDateTimePatternGenerator* dtpg) WR_ICU_WEAK;
U_CAPI int32_t U_EXPORT2 udatpg_getBestPatternWithOptions(UDateTimePatternGenerator* dtpg, const UChar* skeleton,
                                                          int32_t length, UDateTimePatternMatchOptions options,
                                                          UChar* bestPattern, int32_t capacity, UErrorCode* pErrorCode) WR_ICU_WEAK;
U_CAPI int32_t U_EXPORT2 udatpg_getSkeleton(UDateTimePatternGenerator* unusedDtpg, const UChar* pattern, int32_t length,
                                            UChar* skeleton, int32_t capacity, UErrorCode* pErrorCode) WR_ICU_WEAK;
U_CAPI UDateFormatHourCycle U_EXPORT2 udatpg_getDefaultHourCycle(const UDateTimePatternGenerator* dtpg,
                                                                 UErrorCode* pErrorCode) WR_ICU_WEAK;

// upluralrules.h
typedef struct UPluralRules UPluralRules;
enum UPluralType { UPLURAL_TYPE_CARDINAL, UPLURAL_TYPE_ORDINAL };
U_CAPI UPluralRules* U_EXPORT2 uplrules_openForType(const char* locale, UPluralType type, UErrorCode* status) WR_ICU_WEAK;
U_CAPI void U_EXPORT2 uplrules_close(UPluralRules* uplrules) WR_ICU_WEAK;
U_CAPI int32_t U_EXPORT2 uplrules_selectFormatted(const UPluralRules* uplrules, const struct UFormattedNumber* number,
                                                  UChar* keyword, int32_t capacity, UErrorCode* status) WR_ICU_WEAK;
U_CAPI UEnumeration* U_EXPORT2 uplrules_getKeywords(const UPluralRules* uplrules, UErrorCode* status) WR_ICU_WEAK;

// udisplaycontext.h, ureldatefmt.h
enum UDisplayContext { UDISPCTX_CAPITALIZATION_NONE = (1 << 8) + 0 };
enum UDateRelativeDateTimeFormatterStyle { UDAT_STYLE_LONG, UDAT_STYLE_SHORT, UDAT_STYLE_NARROW };
enum URelativeDateTimeUnit {
    UDAT_REL_UNIT_YEAR,
    UDAT_REL_UNIT_QUARTER,
    UDAT_REL_UNIT_MONTH,
    UDAT_REL_UNIT_WEEK,
    UDAT_REL_UNIT_DAY,
    UDAT_REL_UNIT_HOUR,
    UDAT_REL_UNIT_MINUTE,
    UDAT_REL_UNIT_SECOND,
};
typedef struct URelativeDateTimeFormatter URelativeDateTimeFormatter;
typedef void* UNumberFormat;
U_CAPI URelativeDateTimeFormatter* U_EXPORT2 ureldatefmt_open(const char* locale, UNumberFormat* nfToAdopt,
                                                              UDateRelativeDateTimeFormatterStyle width,
                                                              UDisplayContext capitalizationContext, UErrorCode* status) WR_ICU_WEAK;
U_CAPI void U_EXPORT2 ureldatefmt_close(URelativeDateTimeFormatter* reldatefmt) WR_ICU_WEAK;
U_CAPI int32_t U_EXPORT2 ureldatefmt_formatNumeric(const URelativeDateTimeFormatter* reldatefmt, double offset,
                                                   URelativeDateTimeUnit unit, UChar* result, int32_t resultCapacity,
                                                   UErrorCode* status) WR_ICU_WEAK;
U_CAPI int32_t U_EXPORT2 ureldatefmt_format(const URelativeDateTimeFormatter* reldatefmt, double offset,
                                            URelativeDateTimeUnit unit, UChar* result, int32_t resultCapacity,
                                            UErrorCode* status) WR_ICU_WEAK;

// ulistformatter.h (ulistfmt_openForType: ICU 67)
typedef struct UListFormatter UListFormatter;
enum UListFormatterType { ULISTFMT_TYPE_AND, ULISTFMT_TYPE_OR, ULISTFMT_TYPE_UNITS };
enum UListFormatterWidth { ULISTFMT_WIDTH_WIDE, ULISTFMT_WIDTH_SHORT, ULISTFMT_WIDTH_NARROW };
U_CAPI UListFormatter* U_EXPORT2 ulistfmt_openForType(const char* locale, UListFormatterType type,
                                                      UListFormatterWidth width, UErrorCode* status) WR_ICU_WEAK;
U_CAPI void U_EXPORT2 ulistfmt_close(UListFormatter* listfmt) WR_ICU_WEAK;
U_CAPI int32_t U_EXPORT2 ulistfmt_format(const UListFormatter* listfmt, const UChar* const strings[],
                                         const int32_t* stringLengths, int32_t stringCount, UChar* result,
                                         int32_t resultCapacity, UErrorCode* status) WR_ICU_WEAK;

// ucol.h
typedef struct UCollator UCollator;
enum UCollationResult { UCOL_EQUAL = 0, UCOL_GREATER = 1, UCOL_LESS = -1 };
enum UColAttribute {
    UCOL_FRENCH_COLLATION,
    UCOL_ALTERNATE_HANDLING,
    UCOL_CASE_FIRST,
    UCOL_CASE_LEVEL,
    UCOL_NORMALIZATION_MODE,
    UCOL_STRENGTH,
    UCOL_HIRAGANA_QUATERNARY_MODE,
    UCOL_NUMERIC_COLLATION,
};
enum UColAttributeValue {
    UCOL_DEFAULT = -1,
    UCOL_PRIMARY = 0,
    UCOL_SECONDARY = 1,
    UCOL_TERTIARY = 2,
    UCOL_OFF = 16,
    UCOL_ON = 17,
    UCOL_SHIFTED = 20,
    UCOL_NON_IGNORABLE = 21,
    UCOL_LOWER_FIRST = 24,
    UCOL_UPPER_FIRST = 25,
};
U_CAPI UCollator* U_EXPORT2 ucol_open(const char* loc, UErrorCode* status) WR_ICU_WEAK;
U_CAPI void U_EXPORT2 ucol_close(UCollator* coll) WR_ICU_WEAK;
U_CAPI UCollationResult U_EXPORT2 ucol_strcoll(const UCollator* coll, const UChar* source, int32_t sourceLength,
                                               const UChar* target, int32_t targetLength) WR_ICU_WEAK;
U_CAPI void U_EXPORT2 ucol_setAttribute(UCollator* coll, UColAttribute attr, UColAttributeValue value,
                                        UErrorCode* status) WR_ICU_WEAK;
U_CAPI UColAttributeValue U_EXPORT2 ucol_getAttribute(const UCollator* coll, UColAttribute attr, UErrorCode* status) WR_ICU_WEAK;
