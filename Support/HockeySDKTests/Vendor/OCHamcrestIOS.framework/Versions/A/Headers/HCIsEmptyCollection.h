//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCHasCount.h>


/*!
 * @abstract Matches empty collections.
 */
@interface HCIsEmptyCollection : HCHasCount

- (instancetype)init;

@end


FOUNDATION_EXPORT id HC_isEmpty(void);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches any examined object whose <code>-count</code> method
 * returns zero.
 *
 * <b>Example</b><br />
 * <pre>assertThat(\@[], isEmpty())</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_isEmpty instead.
 */
static inline id isEmpty(void)
{
    return HC_isEmpty();
}
#endif
