//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCBaseMatcher.h>


/*!
 * @abstract Tests if string that contains a list of substrings in relative order.
 */
@interface HCStringContainsInOrder : HCBaseMatcher

- (instancetype)initWithSubstrings:(NSArray *)substrings;

@end


FOUNDATION_EXPORT id HC_stringContainsInOrderIn(NSArray *substrings);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates matcher for NSStrings that matches when the examined string contains all of the
 * specified substrings, considering the order of their appearance.
 * @param substrings An array of strings.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(\@"myfoobarbaz", stringContainsInOrderIn(\@[\@"bar", \@"foo"]))</pre>
 * fails as "foo" occurs before "bar" in the string "myfoobarbaz"
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_stringContainsInOrderIn instead.
 */
static inline id stringContainsInOrderIn(NSArray *substrings)
{
    return HC_stringContainsInOrderIn(substrings);
}
#endif


FOUNDATION_EXPORT id HC_stringContainsInOrder(NSString *substrings, ...) NS_REQUIRES_NIL_TERMINATION;

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates matcher for NSStrings that matches when the examined string contains all of the
 * specified substrings, considering the order of their appearance.
 * @param substrings... A comma-separated list of strings, ending with <code>nil</code>.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(\@"myfoobarbaz", stringContainsInOrder(\@"bar", \@"foo", nil))</pre>
 * fails as "foo" occurs before "bar" in the string "myfoobarbaz"
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_stringContainsInOrder instead.
 */
#define stringContainsInOrder(substrings...) HC_stringContainsInOrder(substrings)
#endif
