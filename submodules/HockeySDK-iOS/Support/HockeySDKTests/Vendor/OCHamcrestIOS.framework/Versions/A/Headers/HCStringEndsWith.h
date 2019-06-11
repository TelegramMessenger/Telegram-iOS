//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCSubstringMatcher.h>


/*!
 * @abstract Tests if string ends with a substring.
 */
@interface HCStringEndsWith : HCSubstringMatcher
@end


FOUNDATION_EXPORT id HC_endsWith(NSString *suffix);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is a string that ends with the
 * specified string.
 * @param suffix The substring that the returned matcher will expect at the end of any examined
 * string. (Must not be <code>nil</code>.)
 * @discussion The matcher invokes <code>-hasSuffix:</code> on the examined object, passing the
 * specified <em>suffix</em>.
 *
 * <b>Example</b><br />
 * <pre>assertThat(\@"myStringOfNote", endsWith(\@"Note"))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_endsWith instead.
 */
static inline id endsWith(NSString *suffix)
{
    return HC_endsWith(suffix);
}
#endif
