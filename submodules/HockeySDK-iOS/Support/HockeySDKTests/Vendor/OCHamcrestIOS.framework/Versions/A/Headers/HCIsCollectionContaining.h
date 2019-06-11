//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCDiagnosingMatcher.h>


/*!
 * @abstract Matches if any item in a collection satisfies a nested matcher.
 */
@interface HCIsCollectionContaining : HCDiagnosingMatcher

- (instancetype)initWithMatcher:(id <HCMatcher>)elementMatcher;

@end


FOUNDATION_EXPORT id HC_hasItem(id itemMatcher);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract hasItem(itemMatcher) -
 * Creates a matcher for collections that matches when at least one item in the examined collection
 * satisfies the specified matcher.
 * @param itemMatcher The matcher to apply to collection elements, or an expected value
 * for <em>equalTo</em> matching.
 * @discussion This matcher works on any collection that conforms to the NSFastEnumeration protocol,
 * performing a single pass.
 *
 * If <em>itemMatcher</em> is not a matcher, it is implicitly wrapped in an <em>equalTo</em> matcher
 * to check for equality.
 *
 * <b>Example</b><br />
 * <pre>assertThat(\@[\@1, \@2, \@3], hasItem(equalTo(\@2)))</pre>
 *
 * <pre>assertThat(\@[\@1, \@2, \@3], hasItem(\@2))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_hasItem instead.
 */
#define hasItem HC_hasItem
#endif


FOUNDATION_EXPORT id HC_hasItemsIn(NSArray *itemMatchers);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher for collections that matches when all specified matchers are
 * satisfied by any item in the examined collection.
 * @param itemMatchers An array of matchers. Any element that is not a matcher is implicitly wrapped
 * in an <em>equalTo</em> matcher to check for equality.
 * @discussion This matcher works on any collection that conforms to the NSFastEnumeration protocol,
 * performing one pass for each matcher.
 *
 * <b>Example</b><br />
 * <pre>assertThat(\@[\@"foo", \@"bar", \@"baz"], hasItems(\@[endsWith(\@"z"), endsWith(\@"o")]))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_hasItemsIn instead.
 */
static inline id hasItemsIn(NSArray *itemMatchers)
{
    return HC_hasItemsIn(itemMatchers);
}
#endif


FOUNDATION_EXPORT id HC_hasItems(id itemMatchers, ...) NS_REQUIRES_NIL_TERMINATION;

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher for collections that matches when all specified matchers are
 * satisfied by any item in the examined collection.
 * @param itemMatchers... A comma-separated list of matchers ending with <code>nil</code>.
 * Any argument that is not a matcher is implicitly wrapped in an <em>equalTo</em> matcher to check
 * for equality.
 * @discussion This matcher works on any collection that conforms to the NSFastEnumeration protocol,
 * performing one pass for each matcher.
 *
 * <b>Example</b><br />
 * <pre>assertThat(\@[\@"foo", \@"bar", \@"baz"], hasItems(endsWith(\@"z"), endsWith(\@"o"), nil))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_hasItems instead.
 */
#define hasItems(itemMatchers...) HC_hasItems(itemMatchers)
#endif
