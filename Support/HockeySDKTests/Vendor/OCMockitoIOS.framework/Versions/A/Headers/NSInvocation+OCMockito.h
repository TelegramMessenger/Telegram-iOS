//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 Jonathan M. Reid. See LICENSE.txt

#import <Foundation/Foundation.h>

/*!
 * @abstract NSInvocation helper methods
 */
@interface NSInvocation (OCMockito)

/*!
 * @abstract Returns all invocation arguments in an NSArray.
 * @discussion Non-object arguments are boxed as follows:
 * <ul>
 *   <li><code>nil</code>: NSNull</li>
 *   <li>Primitive numeric values: NSNumber</li>
 *   <li>Pointers: NSValue</li>
 *   <li>Selectors: NSString</li>
 *   <li>Structs: NSData</li>
 * </ul>
 */
- (NSArray *)mkt_arguments;

/*! @abstract Sets invocation return value. */
- (void)mkt_setReturnValue:(id)returnValue;

/*! @abstract Retains arguments but with weak invocation target to avoid retain cycles. */
- (void)mkt_retainArgumentsWithWeakTarget;

@end
