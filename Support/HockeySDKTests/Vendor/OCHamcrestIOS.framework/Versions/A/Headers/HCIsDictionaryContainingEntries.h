//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCDiagnosingMatcher.h>


/*!
 * @abstract Matches if dictionary contains entries that satisfy the list of keys and value
 * matchers.
 */
@interface HCIsDictionaryContainingEntries : HCDiagnosingMatcher

- (instancetype)initWithKeys:(NSArray *)keys
               valueMatchers:(NSArray *)valueMatchers;

@end

FOUNDATION_EXPORT id HC_hasEntriesIn(NSDictionary *valueMatchersForKeys);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher for NSDictionaries that matches when the examined dictionary contains
 * entries satisfying a dictionary of keys and their value matchers.
 * @param valueMatchersForKeys A dictionary of keys (not matchers) and their value matchers. Any
 * value argument that is not a matcher is implicitly wrapped in an <em>equalTo</em> matcher to
 * check for equality.
 * @discussion
 * <b>Examples</b><br />
 * <pre>assertThat(personDict, hasEntriesIn(\@{\@"firstName": equalTo(\@"Jon"), \@"lastName": equalTo(\@"Reid")}))</pre>
 * <pre>assertThat(personDict, hasEntriesIn(\@{\@"firstName": \@"Jon", \@"lastName": \@"Reid"}))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_hasEntryIn instead.
 */
static inline id hasEntriesIn(NSDictionary *valueMatchersForKeys)
{
    return HC_hasEntriesIn(valueMatchersForKeys);
}
#endif

FOUNDATION_EXPORT id HC_hasEntries(id keysAndValueMatchers, ...) NS_REQUIRES_NIL_TERMINATION;

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher for NSDictionaries that matches when the examined dictionary contains
 * entries satisfying a list of alternating keys and their value matchers.
 * @param keysAndValueMatchers... A key (not a matcher) to look up, followed by a value matcher or
 * an expected value for <em>equalTo</em> matching, in a comma-separated list ending
 * with <code>nil</code>
 * @discussion Note that the keys must be actual keys, not matchers. Any value argument that is not
 * a matcher is implicitly wrapped in an <em>equalTo</em> matcher to check for equality.
 *
 * <b>Examples</b><br />
 * <pre>assertThat(personDict, hasEntries(\@"firstName", equalTo(\@"Jon"), \@"lastName", equalTo(\@"Reid"), nil))</pre>
 * <pre>assertThat(personDict, hasEntries(\@"firstName", \@"Jon", \@"lastName", \@"Reid", nil))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_hasEntry instead.
 */
#define hasEntries(keysAndValueMatchers...) HC_hasEntries(keysAndValueMatchers)
#endif
