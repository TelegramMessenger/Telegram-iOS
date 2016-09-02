//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCBaseMatcher.h>


/*!
 * @abstract Matches anything.
 */
@interface HCIsAnything : HCBaseMatcher

- (instancetype)init;
- (instancetype)initWithDescription:(NSString *)description;

@end


FOUNDATION_EXPORT id HC_anything(void);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that always matches, regardless of the examined object.
 * @discussion
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_anything instead.
 */
static inline id anything(void)
{
    return HC_anything();
}
#endif


FOUNDATION_EXPORT id HC_anythingWithDescription(NSString *description);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches anything, regardless of the examined object, but
 * describes itself with the specified NSString.
 * @param description A meaningful string used to describe this matcher.
 * @discussion
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_anything instead.
 */
static inline id anythingWithDescription(NSString *description)
{
    return HC_anythingWithDescription(description);
}
#endif
