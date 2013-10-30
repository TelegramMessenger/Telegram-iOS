#import <Foundation/Foundation.h>

@class HCTestFailure;


/**
    Chain-of-responsibility for handling test failures.
 
    @ingroup integration
 */
@protocol HCTestFailureHandler <NSObject>

@property (nonatomic, strong) id <HCTestFailureHandler> successor;

/**
    Handle test failure at specific location, or pass to successor.
 */
- (void)handleFailure:(HCTestFailure *)failure;

@end
