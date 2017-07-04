#import <Foundation/Foundation.h>

@class MTSignal;
@class MTContext;

@interface MTBackupAddressSignals : NSObject

+ (MTSignal *)fetchBackupIps:(bool)isTestingEnvironment currentContext:(MTContext *)currentContext;

@end
