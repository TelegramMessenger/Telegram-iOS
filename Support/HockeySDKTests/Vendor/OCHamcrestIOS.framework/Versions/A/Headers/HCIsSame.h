//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCBaseMatcher.h>


/*!
 * @abstract Is the value the same object as another value?
 */
@interface HCIsSame : HCBaseMatcher

- (instancetype)initSameAs:(id)object;

@end


FOUNDATION_EXPORT id HC_sameInstance(id expectedInstance);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches only when the examined object is the same instance as
 * the specified target object.
 * @param expectedInstance The expected instance.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(delegate, sameInstance(expectedDelegate))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_sameInstance instead.
 */
static inline id sameInstance(id expectedInstance)
{
    return HC_sameInstance(expectedInstance);
}
#endif
