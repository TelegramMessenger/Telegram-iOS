//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt
//  Contribution by Justin Shacklette

#import <OCHamcrestIOS/HCDiagnosingMatcher.h>


/*!
 * @abstract Matches objects whose "property" (or simple method) satisfies a nested matcher.
 */
@interface HCHasProperty : HCDiagnosingMatcher

- (instancetype)initWithProperty:(NSString *)propertyName value:(id <HCMatcher>)valueMatcher;

@end


FOUNDATION_EXPORT id HC_hasProperty(NSString *propertyName, id valueMatcher);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object has an instance method with the
 * specified name whose return value satisfies the specified matcher.
 * @param propertyName The name of an instance method without arguments that returns an object.
 * @param valueMatcher The matcher to satisfy for the return value, or an expected value for
 * <em>equalTo</em> matching.
 * @discussion Note: While this matcher factory is called "hasProperty", it applies to the return
 * values of any instance methods without arguments, not just properties.
 *
 * <b>Examples</b><br />
 * <pre>assertThat(person, hasProperty(\@"firstName", equalTo(\@"Joe")))</pre>
 * <pre>assertThat(person, hasProperty(\@"firstName", \@"Joe"))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_hasProperty instead.
 */
static inline id hasProperty(NSString *propertyName, id valueMatcher)
{
    return HC_hasProperty(propertyName, valueMatcher);
}
#endif
