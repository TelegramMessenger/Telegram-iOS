//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 hamcrest.org. See LICENSE.txt

#import <Foundation/Foundation.h>


/*!
 * @abstract A description of an @ref HCMatcher.
 * @discussion An @ref HCMatcher will describe itself to a description which can later be used for reporting.
 */
@protocol HCDescription <NSObject>

/*!
 * @abstract Appends some plain text to the description.
 * @return <code>self</code>, for chaining.
 */
- (id <HCDescription>)appendText:(NSString *)text;

/*!
 * @abstract Appends description of specified value to description.
 * @discussion If the value implements the @ref HCSelfDescribing protocol, then it will be used.
 * @return <code>self</code>, for chaining.
 */
- (id <HCDescription>)appendDescriptionOf:(id)value;

/*!
 * @abstract Appends a list of objects to the description.
 * @return <code>self</code>, for chaining.
 */
- (id <HCDescription>)appendList:(NSArray *)values
                          start:(NSString *)start
                      separator:(NSString *)separator
                            end:(NSString *)end;

@end
