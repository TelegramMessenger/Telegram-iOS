//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCIsAnything.h>


/*!
 * @abstract Matches anything, capturing all values.
 * @discussion This matcher captures all values it was given to match, and always evaluates to
 * <code>YES</code>. Use it to capture argument values for further assertions.
 *
 * Unlike other matchers which are usually transient, this matcher should be created outside of any
 * expression so that it can be queried for the items it captured.
 */
@interface HCArgumentCaptor : HCIsAnything

/*!
 * @abstract Returns the captured value.
 * @discussion If <code>-matches:</code> was called more than once then this property returns the
 * last captured value.
 *
 * If <code>-matches:</code> was never invoked and so no value was captured, this property returns
 * <code>nil</code>. But if <code>nil</code> was captured, this property returns NSNull.
 */
@property (nonatomic, readonly) id value;

/*!
 * @abstract Returns all captured values.
 * @discussion Returns an array containing all captured values, in the order in which they were
 * captured. <code>nil</code> values are converted to NSNull.
 */
@property (nonatomic, readonly) NSArray *allValues;

@end
