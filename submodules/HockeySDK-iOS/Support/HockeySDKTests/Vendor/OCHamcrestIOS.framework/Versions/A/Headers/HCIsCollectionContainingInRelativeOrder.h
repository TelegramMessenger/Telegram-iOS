//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCDiagnosingMatcher.h>


/*!
 * @abstract Matches if every item in a collection satisfies a list of nested matchers, in order.
 */
@interface HCIsCollectionContainingInRelativeOrder : HCDiagnosingMatcher

- (instancetype)initWithMatchers:(NSArray *)itemMatchers;

@end


FOUNDATION_EXPORT id HC_containsInRelativeOrder(NSArray *itemMatchers);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher for collections that matches when the examined collection contains
 * items satisfying the specified list of matchers, in the same relative order.
 * @param itemMatchers Array of matchers that must be satisfied by the items provided by the
 * examined collection in the same relative order.
 * @discussion This matcher works on any collection that conforms to the NSFastEnumeration protocol,
 * performing a single pass.
 *
 * Any element of <em>itemMatchers</em> that is not a matcher is implicitly wrapped in an
 * <em>equalTo</em> matcher to check for equality.
 *
 * <b>Examples</b><br />
 * <pre>assertThat(\@[\@1, \@2, \@3, \@4, \@5], containsInRelativeOrder(equalTo(\@2), equalTo(\@4)))</pre>
 * <pre>assertThat(\@[\@1, \@2, \@3, \@4, \@5], containsInRelativeOrder(\@2, \@4))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_containsInRelativeOrder instead.
 */
static inline id containsInRelativeOrder(NSArray *itemMatchers)
{
    return HC_containsInRelativeOrder(itemMatchers);
}
#endif
