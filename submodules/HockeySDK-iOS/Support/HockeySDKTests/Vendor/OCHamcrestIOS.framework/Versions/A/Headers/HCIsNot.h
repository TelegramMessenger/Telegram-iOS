//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCBaseMatcher.h>


/*!
 * @abstract Calculates the logical negation of a matcher.
 */
@interface HCIsNot : HCBaseMatcher

- (instancetype)initWithMatcher:(id <HCMatcher>)matcher;

@end


FOUNDATION_EXPORT id HC_isNot(id value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that wraps an existing matcher, but inverts the logic by which it
 * will match.
 * @param value The matcher to negate, or an expected value to match for inequality.
 * @discussion If <em>value</em> is not a matcher, it is implicitly wrapped in an <em>equalTo</em>
 * matcher to check for equality, and thus matches for inequality.
 *
 * <b>Examples</b><br />
 * <pre>assertThat(cheese, isNot(equalTo(smelly)))</pre>
 * <pre>assertThat(cheese, isNot(smelly))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_isNot instead.
 */
static inline id isNot(id value)
{
    return HC_isNot(value);
}
#endif
