//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCBaseMatcher.h>


/*!
 * @abstract Matches true values.
 */
@interface HCIsTrue : HCBaseMatcher
@end

/*!
 * @abstract Matches false values.
 */
@interface HCIsFalse : HCBaseMatcher
@end


FOUNDATION_EXPORT id HC_isTrue(void);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is an non-zero NSNumber.
 * @discussion
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_isTrue instead.
 */
static inline id isTrue(void)
{
    return HC_isTrue();
}
#endif


FOUNDATION_EXPORT id HC_isFalse(void);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is NSNumber zero.
 * @discussion
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_isFalse instead.
*/
static inline id isFalse(void)
{
    return HC_isFalse();
}
#endif
