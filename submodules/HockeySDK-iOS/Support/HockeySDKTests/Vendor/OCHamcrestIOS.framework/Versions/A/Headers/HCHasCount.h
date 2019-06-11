//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCBaseMatcher.h>


/*!
 * @abstract Matches if collection size satisfies a nested matcher.
 */
@interface HCHasCount : HCBaseMatcher

- (instancetype)initWithMatcher:(id <HCMatcher>)countMatcher;

@end


FOUNDATION_EXPORT id HC_hasCount(id <HCMatcher> countMatcher);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object's <code>-count</code> method
 * returns a value that satisfies the specified matcher.
 * @param countMatcher A matcher for the count of an examined collection.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(\@[\@"foo", \@"bar"], hasCount(equalTo(@2)))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_hasCount instead.
 */
static inline id hasCount(id <HCMatcher> countMatcher)
{
    return HC_hasCount(countMatcher);
}
#endif


FOUNDATION_EXPORT id HC_hasCountOf(NSUInteger count);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object's <code>-count</code> method
 * returns a value that equals the specified value.
 * @param value Value to compare against as the expected count.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(\@[\@"foo", \@"bar"], hasCountOf(2))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_hasCountOf instead.
 */
static inline id hasCountOf(NSUInteger value)
{
    return HC_hasCountOf(value);
}
#endif
