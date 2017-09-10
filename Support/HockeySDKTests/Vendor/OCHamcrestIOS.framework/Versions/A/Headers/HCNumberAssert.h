//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <Foundation/Foundation.h>

@protocol HCMatcher;


FOUNDATION_EXPORT void HC_assertThatBoolWithLocation(id testCase, BOOL actual,
        id <HCMatcher> matcher, char const *fileName, int lineNumber);

#define HC_assertThatBool(actual, matcher)  \
    HC_assertThatBoolWithLocation(self, actual, matcher, __FILE__, __LINE__)

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract assertThatBool(actual, matcher) -
 * Asserts that BOOL actual value, converted to an NSNumber, satisfies matcher.
 * @param actual The BOOL value to convert to an NSNumber for evaluation.
 * @param matcher The matcher to satisfy as the expected condition.
 * @discussion Consider using <code>assertThat(\@(actual), matcher)</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_assertThatBool instead.
 */
#define assertThatBool(actual, matcher) HC_assertThatBool(actual, matcher)
#endif


FOUNDATION_EXPORT void HC_assertThatCharWithLocation(id testCase, char actual,
        id <HCMatcher> matcher, char const *fileName, int lineNumber);

#define HC_assertThatChar(actual, matcher)  \
    HC_assertThatCharWithLocation(self, actual, matcher, __FILE__, __LINE__)

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract assertThatChar(actual, matcher) -
 * Asserts that char actual value, converted to an NSNumber, satisfies matcher.
 * @param actual The char value to convert to an NSNumber for evaluation.
 * @param matcher The matcher to satisfy as the expected condition.
 * @discussion Consider using <code>assertThat(\@(actual), matcher)</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_assertThatChar instead.
 */
#define assertThatChar(actual, matcher) HC_assertThatChar(actual, matcher)
#endif


FOUNDATION_EXPORT void HC_assertThatDoubleWithLocation(id testCase, double actual,
        id <HCMatcher> matcher, char const *fileName, int lineNumber);

#define HC_assertThatDouble(actual, matcher)  \
    HC_assertThatDoubleWithLocation(self, actual, matcher, __FILE__, __LINE__)

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract HC_assertThatDouble(actual, matcher) -
 * Asserts that double actual value, converted to an NSNumber, satisfies matcher.
 * @param actual The double value to convert to an NSNumber for evaluation.
 * @param matcher The matcher to satisfy as the expected condition.
 * @discussion Consider using <code>assertThat(\@(actual), matcher)</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_assertThatDouble instead.
 */
#define assertThatDouble(actual, matcher) HC_assertThatDouble(actual, matcher)
#endif


FOUNDATION_EXPORT void HC_assertThatFloatWithLocation(id testCase, float actual,
        id <HCMatcher> matcher, char const *fileName, int lineNumber);

#define HC_assertThatFloat(actual, matcher)  \
    HC_assertThatFloatWithLocation(self, actual, matcher, __FILE__, __LINE__)

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract assertThatFloat(actual, matcher) -
 * Asserts that float actual value, converted to an NSNumber, satisfies matcher.
 * @param actual The float value to convert to an NSNumber for evaluation.
 * @param matcher The matcher to satisfy as the expected condition.
 * @discussion Consider using <code>assertThat(\@(actual), matcher)</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_assertThatFloat instead.
 */
#define assertThatFloat(actual, matcher) HC_assertThatFloat(actual, matcher)
#endif


FOUNDATION_EXPORT void HC_assertThatIntWithLocation(id testCase, int actual,
        id <HCMatcher> matcher, char const *fileName, int lineNumber);

#define HC_assertThatInt(actual, matcher)  \
    HC_assertThatIntWithLocation(self, actual, matcher, __FILE__, __LINE__)

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract assertThatInt(actual, matcher) -
 * Asserts that int actual value, converted to an NSNumber, satisfies matcher.
 * @param actual The int value to convert to an NSNumber for evaluation.
 * @param matcher The matcher to satisfy as the expected condition.
 * @discussion Consider using <code>assertThat(\@(actual), matcher)</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_assertThatInt instead.
 */
#define assertThatInt(actual, matcher) HC_assertThatInt(actual, matcher)
#endif


FOUNDATION_EXPORT void HC_assertThatLongWithLocation(id testCase, long actual,
        id <HCMatcher> matcher, char const *fileName, int lineNumber);

#define HC_assertThatLong(actual, matcher)  \
    HC_assertThatLongWithLocation(self, actual, matcher, __FILE__, __LINE__)

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract assertThatLong(actual, matcher) -
 * Asserts that long actual value, converted to an NSNumber, satisfies matcher.
 * @param actual The long value to convert to an NSNumber for evaluation.
 * @param matcher The matcher to satisfy as the expected condition.
 * @discussion Consider using <code>assertThat(\@(actual), matcher)</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_assertThatLong instead.
 */
#define assertThatLong(actual, matcher) HC_assertThatLong(actual, matcher)
#endif


FOUNDATION_EXPORT void HC_assertThatLongLongWithLocation(id testCase, long long actual,
        id <HCMatcher> matcher, char const *fileName, int lineNumber);

#define HC_assertThatLongLong(actual, matcher)  \
    HC_assertThatLongLongWithLocation(self, actual, matcher, __FILE__, __LINE__)

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract assertThatLongLong(actual, matcher) -
 * Asserts that <code>long long</code> actual value, converted to an NSNumber, satisfies matcher.
 * @param actual The long long value to convert to an NSNumber for evaluation.
 * @param matcher The matcher to satisfy as the expected condition.
 * @discussion Consider using <code>assertThat(\@(actual), matcher)</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_assertThatLongLong instead.
 */
#define assertThatLongLong(actual, matcher) HC_assertThatLongLong(actual, matcher)
#endif


FOUNDATION_EXPORT void HC_assertThatShortWithLocation(id testCase, short actual,
        id <HCMatcher> matcher, char const *fileName, int lineNumber);

#define HC_assertThatShort(actual, matcher)  \
    HC_assertThatShortWithLocation(self, actual, matcher, __FILE__, __LINE__)

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract assertThatShort(actual, matcher) -
 * Asserts that short actual value, converted to an NSNumber, satisfies matcher.
 * @param actual The short value to convert to an NSNumber for evaluation.
 * @param matcher The matcher to satisfy as the expected condition.
 * @discussion Consider using <code>assertThat(\@(actual), matcher)</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_assertThatShort instead.
 */
#define assertThatShort(actual, matcher) HC_assertThatShort(actual, matcher)
#endif


FOUNDATION_EXPORT void HC_assertThatUnsignedCharWithLocation(id testCase, unsigned char actual,
        id <HCMatcher> matcher, char const *fileName, int lineNumber);

#define HC_assertThatUnsignedChar(actual, matcher)  \
    HC_assertThatUnsignedCharWithLocation(self, actual, matcher, __FILE__, __LINE__)

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract assertThatUnsignedChar(actual, matcher) -
 * Asserts that unsigned char actual value, converted to an NSNumber, satisfies matcher.
 * @param actual The unsigned char value to convert to an NSNumber for evaluation.
 * @param matcher The matcher to satisfy as the expected condition.
 * @discussion Consider using <code>assertThat(\@(actual), matcher)</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_assertThatUnsignedChar instead.
 */
#define assertThatUnsignedChar(actual, matcher) HC_assertThatUnsignedChar(actual, matcher)
#endif


FOUNDATION_EXPORT void HC_assertThatUnsignedIntWithLocation(id testCase, unsigned int actual,
        id <HCMatcher> matcher, char const *fileName, int lineNumber);

#define HC_assertThatUnsignedInt(actual, matcher)  \
    HC_assertThatUnsignedIntWithLocation(self, actual, matcher, __FILE__, __LINE__)

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract assertThatUnsignedInt(actual, matcher) -
 * Asserts that unsigned int actual value, converted to an NSNumber, satisfies matcher.
 * @param actual The unsigned int value to convert to an NSNumber for evaluation.
 * @param matcher  The matcher to satisfy as the expected condition.
 * @discussion Consider using <code>assertThat(\@(actual), matcher)</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_assertThatUnsignedInt instead.
 */
#define assertThatUnsignedInt(actual, matcher) HC_assertThatUnsignedInt(actual, matcher)
#endif


FOUNDATION_EXPORT void HC_assertThatUnsignedLongWithLocation(id testCase, unsigned long actual,
        id <HCMatcher> matcher, char const *fileName, int lineNumber);

#define HC_assertThatUnsignedLong(actual, matcher)  \
    HC_assertThatUnsignedLongWithLocation(self, actual, matcher, __FILE__, __LINE__)

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract assertThatUnsignedLong(actual, matcher) -
 * Asserts that unsigned long actual value, converted to an NSNumber, satisfies matcher.
 * @param actual The unsigned long value to convert to an NSNumber for evaluation.
 * @param matcher The matcher to satisfy as the expected condition.
 * @discussion Consider using <code>assertThat(\@(actual), matcher)</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_assertThatUnsignedLong instead.
 */
#define assertThatUnsignedLong(actual, matcher) HC_assertThatUnsignedLong(actual, matcher)
#endif


FOUNDATION_EXPORT void HC_assertThatUnsignedLongLongWithLocation(id testCase, unsigned long long actual,
        id <HCMatcher> matcher, char const *fileName, int lineNumber);

#define HC_assertThatUnsignedLongLong(actual, matcher)  \
    HC_assertThatUnsignedLongLongWithLocation(self, actual, matcher, __FILE__, __LINE__)

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract assertThatUnsignedLongLong(actual, matcher) -
 * Asserts that unsigned long long actual value, converted to an NSNumber, satisfies matcher.
 * @param actual The unsigned long long value to convert to an NSNumber for evaluation.
 * @param matcher  The matcher to satisfy as the expected condition.
 * @discussion Consider using <code>assertThat(\@(actual), matcher)</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_assertThatUnsignedLongLong instead.
 */
#define assertThatUnsignedLongLong(actual, matcher) HC_assertThatUnsignedLongLong(actual, matcher)
#endif


FOUNDATION_EXPORT void HC_assertThatUnsignedShortWithLocation(id testCase, unsigned short actual,
        id <HCMatcher> matcher, char const *fileName, int lineNumber);

#define HC_assertThatUnsignedShort(actual, matcher)  \
    HC_assertThatUnsignedShortWithLocation(self, actual, matcher, __FILE__, __LINE__)

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract assertThatUnsignedShort(actual, matcher) -
 * Asserts that unsigned short actual value, converted to an NSNumber, satisfies matcher.
 * @param actual The unsigned short value to convert to an NSNumber for evaluation.
 * @param matcher The matcher to satisfy as the expected condition.
 * @discussion Consider using <code>assertThat(\@(actual), matcher)</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_assertThatUnsignedShort instead.
 */
#define assertThatUnsignedShort(actual, matcher) HC_assertThatUnsignedShort(actual, matcher)
#endif


FOUNDATION_EXPORT void HC_assertThatIntegerWithLocation(id testCase, NSInteger actual,
        id <HCMatcher> matcher, char const *fileName, int lineNumber);

#define HC_assertThatInteger(actual, matcher)  \
    HC_assertThatIntegerWithLocation(self, actual, matcher, __FILE__, __LINE__)

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract assertThatInteger(actual, matcher) -
 * Asserts that NSInteger actual value, converted to an NSNumber, satisfies matcher.
 * @param actual The NSInteger value to convert to an NSNumber for evaluation.
 * @param matcher The matcher to satisfy as the expected condition.
 * @discussion Consider using <code>assertThat(\@(actual), matcher)</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_assertThatInteger instead.
 */
#define assertThatInteger(actual, matcher) HC_assertThatInteger(actual, matcher)
#endif


FOUNDATION_EXPORT void HC_assertThatUnsignedIntegerWithLocation(id testCase, NSUInteger actual,
        id <HCMatcher> matcher, char const *fileName, int lineNumber);

#define HC_assertThatUnsignedInteger(actual, matcher)  \
    HC_assertThatUnsignedIntegerWithLocation(self, actual, matcher, __FILE__, __LINE__)

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract assertThatUnsignedInteger(actual, matcher) -
 * Asserts that NSUInteger actual value, converted to an NSNumber, satisfies matcher.
 * @param actual The NSUInteger value to convert to an NSNumber for evaluation.
 * @param matcher The matcher to satisfy as the expected condition.
 * @discussion Consider using <code>assertThat(\@(actual), matcher)</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_assertThatUnsignedInteger instead.
 */
#define assertThatUnsignedInteger(actual, matcher) HC_assertThatUnsignedInteger(actual, matcher)
#endif
