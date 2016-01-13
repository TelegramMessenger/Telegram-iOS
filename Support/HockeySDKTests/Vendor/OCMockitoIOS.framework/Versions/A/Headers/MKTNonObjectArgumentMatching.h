//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 Jonathan M. Reid. See LICENSE.txt

@protocol HCMatcher;


/*!
 * @abstract Ability to specify OCHamcrest matchers for non-object arguments.
 */
@protocol MKTNonObjectArgumentMatching

/*!
 * @abstract Specifies OCHamcrest matcher for a specific argument of a method.
 * @discussion For methods arguments that take objects, just pass the matcher directly as a method
 * call. But for arguments that take non-objects, pass in a dummy value to satisfy the compiler, but
 * call this to override it with the given matcher. Upon verification, the actual argument received
 * will be converted to an object before being checked by the matcher.
 *
 * The argument index is 0-based, so the first argument of a method has index 0.
 *
 * Examples:
 * <ul>
 *   <li><code>[[given([mockFetchedResultsController performFetch:NULL]) withMatcher:anything()] willReturn:@YES];</code></li>
 * </ul>
 * This stubs <code>performFetch:</code> to return <code>YES</code> for any NSError ** argument.
 * <ul>
 *   <li><code>[[verify(mockArray) withMatcher:greaterThan(@5]) forArgument:0] removeObjectAtIndex:0];</code></li>
 * </ul>
 * This verifies that <code>removeObjectAtIndex:</code> was called with an index greater than 5.
 */
- (id)withMatcher:(id <HCMatcher>)matcher forArgument:(NSUInteger)index;

/*!
 * @abstract Specifies OCHamcrest matcher for the first argument of a method.
 * @discussion Equivalent to <code>withMatcher:matcher forArgument:0</code>.
 *
 * Example:
 * <ul>
 *   <li><code>[[verify(mockArray) withMatcher:greaterThan(@5)] removeObjectAtIndex:0];</code></li>
 * </ul>
 * This verifies that <code>removeObjectAtIndex:</code> was called with an index greater than 5.
*/
- (id)withMatcher:(id <HCMatcher>)matcher;

@end
