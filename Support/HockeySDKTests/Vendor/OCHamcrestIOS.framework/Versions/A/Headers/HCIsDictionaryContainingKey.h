//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCBaseMatcher.h>


/*!
 * @abstract Matches if any entry in a dictionary has a key satisfying the nested matcher.
 */
@interface HCIsDictionaryContainingKey : HCBaseMatcher

- (instancetype)initWithKeyMatcher:(id <HCMatcher>)keyMatcher;

@end


FOUNDATION_EXPORT id HC_hasKey(id keyMatcher);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher for NSDictionaries that matches when the examined dictionary contains
 * at least key that satisfies the specified matcher.
 * @param keyMatcher The matcher to satisfy for the key, or an expected value for <em>equalTo</em> matching.
 * @discussion Any argument that is not a matcher is implicitly wrapped in an <em>equalTo</em>
 * matcher to check for equality.
 *
 * <b>Examples</b><br />
 * <pre>assertThat(myDictionary, hasEntry(equalTo(\@"foo")))</pre>
 * <pre>assertThat(myDictionary, hasEntry(\@"foo"))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_hasKey instead.
 */
static inline id hasKey(id keyMatcher)
{
    return HC_hasKey(keyMatcher);
}
#endif
