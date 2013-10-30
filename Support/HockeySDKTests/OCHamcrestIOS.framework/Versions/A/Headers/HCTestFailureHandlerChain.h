#import <Foundation/Foundation.h>
#import <objc/objc-api.h>

@protocol HCTestFailureHandler;


/**
    Returns chain of test failure handlers.
 
    @ingroup integration
 */
OBJC_EXPORT id <HCTestFailureHandler> HC_testFailureHandlerChain(void);
