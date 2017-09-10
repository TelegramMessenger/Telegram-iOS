//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCDiagnosingMatcher.h>


/*!
 * @abstract Matches if every item in a collection, in any order, satisfy a list of nested matchers.
 */
@interface HCIsCollectionContainingInAnyOrder : HCDiagnosingMatcher

- (instancetype)initWithMatchers:(NSArray *)itemMatchers;

@end


FOUNDATION_EXPORT id HC_containsInAnyOrderIn(NSArray *itemMatchers);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates an order-agnostic matcher for collections that matches when each item in the
 * examined collection satisfies one matcher anywhere in the specified list of matchers.
 * @param itemMatchers An array of matchers. Any element that is not a matcher is implicitly wrapped
 * in an <em>equalTo</em> matcher to check for equality.
 * @discussion This matcher works on any collection that conforms to the NSFastEnumeration protocol,
 * performing a single pass. For a positive match, the examined collection must be of the same
 * length as the specified list of matchers.
 *
 * Note: Each matcher in the specified list will only be used once during a given examination, so
 * be careful when specifying matchers that may be satisfied by more than one entry in an examined
 * collection.
 *
 * <b>Examples</b><br />
 * <pre>assertThat(\@[\@"foo", \@"bar"], containsInAnyOrderIn(\@[equalTo(\@"bar"), equalTo(\@"foo")]))</pre>
 * <pre>assertThat(\@[\@"foo", \@"bar"], containsInAnyOrderIn(@[\@"bar", \@"foo"]))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_containsInAnyOrderIn instead.
 */
static inline id containsInAnyOrderIn(NSArray *itemMatchers)
{
    return HC_containsInAnyOrderIn(itemMatchers);
}
#endif


FOUNDATION_EXPORT id HC_containsInAnyOrder(id itemMatchers, ...) NS_REQUIRES_NIL_TERMINATION;

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates an order-agnostic matcher for collections that matches when each item in the
 * examined collection satisfies one matcher anywhere in the specified list of matchers.
 * @param itemMatchers... A comma-separated list of matchers ending with <code>nil</code>.
 * Any argument that is not a matcher is implicitly wrapped in an <em>equalTo</em> matcher to check
 * for equality.
 * @discussion This matcher works on any collection that conforms to the NSFastEnumeration protocol,
 * performing a single pass. For a positive match, the examined collection must be of the same
 * length as the specified list of matchers.
 *
 * Note: Each matcher in the specified list will only be used once during a given examination, so
 * be careful when specifying matchers that may be satisfied by more than one entry in an examined
 * collection.
 *
 * <b>Examples</b><br />
 * <pre>assertThat(\@[\@"foo", \@"bar"], containsInAnyOrder(equalTo(\@"bar"), equalTo(\@"foo"), nil))</pre>
 * <pre>assertThat(\@[\@"foo", \@"bar"], containsInAnyOrder(\@"bar", \@"foo", nil))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_containsInAnyOrder instead.
 */
#define containsInAnyOrder(itemMatchers...) HC_containsInAnyOrder(itemMatchers)
#endif
