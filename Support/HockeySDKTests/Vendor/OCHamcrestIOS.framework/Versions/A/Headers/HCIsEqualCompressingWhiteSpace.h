//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCBaseMatcher.h>


/*!
 * @abstract Tests if a string is equal to another string, when whitespace differences are (mostly) ignored.
 */
@interface HCIsEqualCompressingWhiteSpace : HCBaseMatcher

- (instancetype)initWithString:(NSString *)string;

@end


FOUNDATION_EXPORT id HC_equalToCompressingWhiteSpace(NSString *expectedString);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher for NSStrings that matches when the examined string is equal to the
 * specified expected string, when whitespace differences are (mostly) ignored.
 * @param expectedString The expected value of matched strings. (Must not be <code>nil</code>.)
 * @discussion To be exact, the following whitespace rules are applied:
 * <ul>
 *   <li>all leading and trailing whitespace of both the <em>expectedString</em> and the examined string are ignored</li>
 *   <li>any remaining whitespace, appearing within either string, is collapsed to a single space before comparison</li>
 * </ul>
 *
 * <b>Example</b><br />
 * <pre>assertThat(\@"   my\tfoo  bar ", equalToCompressingWhiteSpace(\@" my  foo bar"))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_equalToCompressingWhiteSpace instead.
 */
static inline id equalToCompressingWhiteSpace(NSString *expectedString)
{
    return HC_equalToCompressingWhiteSpace(expectedString);
}
#endif
