//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCBaseMatcher.h>


/*!
 * @abstract Matches values with <code>-compare:</code>.
 */
@interface HCOrderingComparison : HCBaseMatcher

- (instancetype)initComparing:(id)expectedValue
                   minCompare:(NSComparisonResult)min
                   maxCompare:(NSComparisonResult)max
        comparisonDescription:(NSString *)comparisonDescription;

@end


FOUNDATION_EXPORT id HC_greaterThan(id value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is greater than the specified
 * value, as reported by the <code>-compare:</code> method of the <b>examined</b> object.
 * @param value The value which, when passed to the <code>-compare:</code> method of the examined
 * object, should return NSOrderedAscending.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(\@2, greaterThan(\@1))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_greaterThan instead.
 */
static inline id greaterThan(id value)
{
    return HC_greaterThan(value);
}
#endif


FOUNDATION_EXPORT id HC_greaterThanOrEqualTo(id value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is greater than or equal to the
 * specified value, as reported by the <code>-compare:</code> method of the <b>examined</b> object.
 * @param value The value which, when passed to the <code>-compare:</code> method of the examined
 * object, should return NSOrderedAscending or NSOrderedSame.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(\@1, greaterThanOrEqualTo(\@1))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_greaterThanOrEqualTo instead.
 */
static inline id greaterThanOrEqualTo(id value)
{
    return HC_greaterThanOrEqualTo(value);
}
#endif


FOUNDATION_EXPORT id HC_lessThan(id value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is less than the specified
 * value, as reported by the <code>-compare:</code> method of the <b>examined</b> object.
 * @param value The value which, when passed to the <code>-compare:</code> method of the examined
 * object, should return NSOrderedDescending.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(\@1, lessThan(\@2))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_lessThan instead.
 */
static inline id lessThan(id value)
{
    return HC_lessThan(value);
}
#endif


FOUNDATION_EXPORT id HC_lessThanOrEqualTo(id value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is less than or equal to the
 * specified value, as reported by the <code>-compare:</code> method of the <b>examined</b> object.
 * @param value The value which, when passed to the <code>-compare:</code> method of the examined
 * object, should return NSOrderedDescending or NSOrderedSame.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(\@1, lessThanOrEqualTo(\@1))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_lessThanOrEqualTo instead.
 */
static inline id lessThanOrEqualTo(id value)
{
    return HC_lessThanOrEqualTo(value);
}
#endif
