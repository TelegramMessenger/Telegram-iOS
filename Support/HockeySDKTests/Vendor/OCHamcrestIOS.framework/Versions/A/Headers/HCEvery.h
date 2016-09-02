//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCDiagnosingMatcher.h>


/*!
 * @abstract Matches if every item in a collection satisfies a nested matcher.
 */
@interface HCEvery : HCDiagnosingMatcher

@property (nonatomic, strong, readonly) id <HCMatcher> matcher;

- (instancetype)initWithMatcher:(id <HCMatcher>)matcher;

@end


FOUNDATION_EXPORT id HC_everyItem(id <HCMatcher> itemMatcher);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher for collections that matches when the examined collection's items are
 * all matched by the specified matcher.
 * @param itemMatcher The matcher to apply to every item provided by the examined collection.
 * @discussion This matcher works on any collection that conforms to the NSFastEnumeration protocol,
 * performing a single pass.
 *
 * <b>Example</b><br />
 * <pre>assertThat(\@[\@"bar", \@"baz"], everyItem(startsWith(\@"ba")))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_everyItem instead.
 */
static inline id everyItem(id <HCMatcher> itemMatcher)
{
    return HC_everyItem(itemMatcher);
}
#endif
