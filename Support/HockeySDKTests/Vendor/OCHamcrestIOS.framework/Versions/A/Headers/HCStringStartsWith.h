//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCSubstringMatcher.h>


/*!
 * @abstract Tests string starts with a substring.
 */
@interface HCStringStartsWith : HCSubstringMatcher
@end


FOUNDATION_EXPORT id HC_startsWith(NSString *prefix);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is a string that starts with
 * the specified string.
 * @param prefix The substring that the returned matcher will expect at the start of any examined
 * string. (Must not be <code>nil</code>.)
 * @discussion The matcher invokes <code>-hasPrefix:</code> on the examined object, passing the
 * specified <em>prefix</em>.
 *
 * <b>Example</b><br />
 * <pre>assertThat(\@"myStringOfNote", startsWith(\@"my"))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_startsWith instead.
 */
static inline id startsWith(NSString *prefix)
{
    return HC_startsWith(prefix);
}
#endif
