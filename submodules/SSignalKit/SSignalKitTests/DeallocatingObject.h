#import <Foundation/Foundation.h>

@interface DeallocatingObject : NSObject

- (instancetype)initWithDeallocated:(bool *)deallocated;

@end
