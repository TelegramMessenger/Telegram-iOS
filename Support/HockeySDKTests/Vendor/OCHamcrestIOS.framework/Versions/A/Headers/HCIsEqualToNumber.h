//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCBaseMatcher.h>


FOUNDATION_EXPORT id HC_equalToChar(char value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is equal to an NSNumber created
 * from the specified char value.
 * @param value The char value from which to create an NSNumber.
 * @discussion Consider using <code>equalTo(\@(value))</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_equalToChar instead.
 */
static inline id equalToChar(char value)
{
    return HC_equalToChar(value);
}
#endif


FOUNDATION_EXPORT id HC_equalToDouble(double value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is equal to an NSNumber created
 * from the specified double value.
 * @param value The double value from which to create an NSNumber.
 * @discussion Consider using <code>equalTo(\@(value))</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_equalToDouble instead.
 */
static inline id equalToDouble(double value)
{
    return HC_equalToDouble(value);
}
#endif


FOUNDATION_EXPORT id HC_equalToFloat(float value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is equal to an NSNumber created
 * from the specified float value.
 * @param value The float value from which to create an NSNumber.
 * @discussion Consider using <code>equalTo(\@(value))</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_equalToFloat instead.
 */
static inline id equalToFloat(float value)
{
    return HC_equalToFloat(value);
}
#endif


FOUNDATION_EXPORT id HC_equalToInt(int value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is equal to an NSNumber created
 * from the specified int value.
 * @param value The int value from which to create an NSNumber.
 * @discussion Consider using <code>equalTo(\@(value))</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_equalToInt instead.
 */
static inline id equalToInt(int value)
{
    return HC_equalToInt(value);
}
#endif


FOUNDATION_EXPORT id HC_equalToLong(long value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is equal to an NSNumber created
 * from the specified long value.
 * @param value The long value from which to create an NSNumber.
 * @discussion Consider using <code>equalTo(\@(value))</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_equalToLong instead.
 */
static inline id equalToLong(long value)
{
    return HC_equalToLong(value);
}
#endif


FOUNDATION_EXPORT id HC_equalToLongLong(long long value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is equal to an NSNumber created
 * from the specified long long value.
 * @param value The long long value from which to create an NSNumber.
 * @discussion Consider using <code>equalTo(\@(value))</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_equalToLongLong instead.
 */
static inline id equalToLongLong(long long value)
{
    return HC_equalToLongLong(value);
}
#endif


FOUNDATION_EXPORT id HC_equalToShort(short value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is equal to an NSNumber created
 * from the specified short value.
 * @param value The short value from which to create an NSNumber.
 * @discussion Consider using <code>equalTo(\@(value))</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_equalToShort instead.
 */
static inline id equalToShort(short value)
{
    return HC_equalToShort(value);
}
#endif


FOUNDATION_EXPORT id HC_equalToUnsignedChar(unsigned char value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract equalToUnsignedChar(value) -
 * Creates a matcher that matches when the examined object is equal to an NSNumber created from the
 * specified unsigned char value.
 * @param value The unsigned char value from which to create an NSNumber.
 * @discussion Consider using <code>equalTo(\@(value))</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_equalToUnsignedChar instead.
 */
static inline id equalToUnsignedChar(unsigned char value)
{
    return HC_equalToUnsignedChar(value);
}
#endif


FOUNDATION_EXPORT id HC_equalToUnsignedInt(unsigned int value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is equal to an NSNumber created
 * from the specified unsigned int value.
 * @param value  The unsigned int value from which to create an NSNumber.
 * @discussion Consider using <code>equalTo(\@(value))</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_equalToUnsignedInt instead.
 */
static inline id equalToUnsignedInt(unsigned int value)
{
    return HC_equalToUnsignedInt(value);
}
#endif


FOUNDATION_EXPORT id HC_equalToUnsignedLong(unsigned long value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is equal to an NSNumber created
 * from the specified unsigned long value.
 * @param value The unsigned long value from which to create an NSNumber.
 * @discussion Consider using <code>equalTo(\@(value))</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_equalToUnsignedLong instead.
 */
static inline id equalToUnsignedLong(unsigned long value)
{
    return HC_equalToUnsignedLong(value);
}
#endif


FOUNDATION_EXPORT id HC_equalToUnsignedLongLong(unsigned long long value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is equal to an NSNumber created
 * from the specified unsigned long long value.
 * @param value The unsigned long long value from which to create an NSNumber.
 * @discussion Consider using <code>equalTo(\@(value))</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_equalToUnsignedLongLong instead.
 */
static inline id equalToUnsignedLongLong(unsigned long long value)
{
    return HC_equalToUnsignedLongLong(value);
}
#endif


FOUNDATION_EXPORT id HC_equalToUnsignedShort(unsigned short value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is equal to an NSNumber created
 * from the specified unsigned short value.
 * @param value The unsigned short value from which to create an NSNumber.
 * @discussion Consider using <code>equalTo(\@(value))</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_equalToUnsignedShort instead.
 */
static inline id equalToUnsignedShort(unsigned short value)
{
    return HC_equalToUnsignedShort(value);
}
#endif


FOUNDATION_EXPORT id HC_equalToInteger(NSInteger value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is equal to an NSNumber created
 * from the specified NSInteger value.
 * @param value The NSInteger value from which to create an NSNumber.
 * @discussion Consider using <code>equalTo(\@(value))</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_equalToInteger instead.
 */
static inline id equalToInteger(NSInteger value)
{
    return HC_equalToInteger(value);
}
#endif


FOUNDATION_EXPORT id HC_equalToUnsignedInteger(NSUInteger value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is equal to an NSNumber created
 * from the specified NSUInteger value.
 * @param value The NSUInteger value from which to create an NSNumber.
 * @discussion Consider using <code>equalTo(\@(value))</code> instead.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_equalToUnsignedInteger instead.
 */
static inline id equalToUnsignedInteger(NSUInteger value)
{
    return HC_equalToUnsignedInteger(value);
}
#endif
