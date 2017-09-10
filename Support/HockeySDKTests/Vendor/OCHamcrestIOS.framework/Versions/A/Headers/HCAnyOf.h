//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCBaseMatcher.h>


/*!
 * @abstract Calculates the logical disjunction of multiple matchers.
 * @discussion Evaluation is shortcut, so subsequent matchers are not called if an earlier matcher
 * returns <code>NO</code>.
 */
@interface HCAnyOf : HCBaseMatcher

- (instancetype)initWithMatchers:(NSArray *)matchers;

@end

FOUNDATION_EXPORT id HC_anyOfIn(NSArray *matchers);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object matches <b>any</b> of the
 * specified matchers.
 * @param matchers An array of matchers. Any element that is not a matcher is implicitly wrapped in
 * an <em>equalTo</em> matcher to check for equality.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(\@"myValue", allOf(\@[startsWith(\@"foo"), containsSubstring(\@"Val")]))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_anyOf instead.
 */
static inline id anyOfIn(NSArray *matchers)
{
    return HC_anyOfIn(matchers);
}
#endif

FOUNDATION_EXPORT id HC_anyOf(id matchers, ...) NS_REQUIRES_NIL_TERMINATION;

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object matches <b>any</b> of the
 * specified matchers.
 * @param matchers... A comma-separated list of matchers ending with <code>nil</code>. Any argument
 * that is not a matcher is implicitly wrapped in an <em>equalTo</em> matcher to check for equality.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(\@"myValue", allOf(startsWith(\@"foo"), containsSubstring(\@"Val"), nil))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_anyOf instead.
 */
#define anyOf(matchers...) HC_anyOf(matchers)
#endif
