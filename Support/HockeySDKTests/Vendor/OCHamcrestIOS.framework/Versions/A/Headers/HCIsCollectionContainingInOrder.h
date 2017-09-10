//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCDiagnosingMatcher.h>


/*!
 * @abstract Matches if every item in a collection satisfies a list of nested matchers, in order.
 */
@interface HCIsCollectionContainingInOrder : HCDiagnosingMatcher

- (instancetype)initWithMatchers:(NSArray *)itemMatchers;

@end


FOUNDATION_EXPORT id HC_containsIn(NSArray *itemMatchers);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher for collections that matches when each item in the examined
 * collection satisfies the corresponding matcher in the specified list of matchers.
 * @param itemMatchers An array of matchers. Any element that is not a matcher is implicitly wrapped
 * in an <em>equalTo</em> matcher to check for equality.
 * @discussion This matcher works on any collection that conforms to the NSFastEnumeration protocol,
 * performing a single pass. For a positive match, the examined collection must be of the same
 * length as the specified list of matchers.
 *
 * <b>Examples</b><br />
 * <pre>assertThat(\@[\@"foo", \@"bar"], containsIn(\@[equalTo(\@"foo"), equalTo(\@"bar")]))</pre>
 * <pre>assertThat(\@[\@"foo", \@"bar"], containsIn(\@[\@"foo", \@"bar"]))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_containsIn instead.)
 */
static inline id containsIn(NSArray *itemMatchers)
{
    return HC_containsIn(itemMatchers);
}
#endif


FOUNDATION_EXPORT id HC_contains(id itemMatchers, ...) NS_REQUIRES_NIL_TERMINATION;

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher for collections that matches when each item in the examined
 * collection satisfies the corresponding matcher in the specified list of matchers.
 * @param itemMatchers... A comma-separated list of matchers ending with <code>nil</code>.
 * Any argument that is not a matcher is implicitly wrapped in an <em>equalTo</em> matcher to check
 * for equality.
 * @discussion This matcher works on any collection that conforms to the NSFastEnumeration protocol,
 * performing a single pass. For a positive match, the examined collection must be of the same
 * length as the specified list of matchers.
 *
 * <b>Examples</b><br />
 * <pre>assertThat(\@[\@"foo", \@"bar"], contains(equalTo(\@"foo"), equalTo(\@"bar"), nil))</pre>
 * <pre>assertThat(\@[\@"foo", \@"bar"], contains(\@"foo", \@"bar", nil))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_contains instead.)
 */
#define contains(itemMatchers...) HC_contains(itemMatchers)
#endif
