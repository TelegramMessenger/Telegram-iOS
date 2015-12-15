//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 Jonathan M. Reid. See LICENSE.txt

#import <Foundation/Foundation.h>


/*!
 * @deprecated Version 2.0.0 Use HCArgumentCaptor instead.
 */
__attribute__ ((deprecated))
@interface MKTArgumentCaptor : NSObject

/*! When switching to HCArgumentCaptor, replace <code>[argument capture]</code> with
 * <code>(id)argument</code>. */
- (id)capture __attribute__ ((deprecated));

- (id)value;
- (NSArray *)allValues;

@end
