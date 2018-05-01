#import <Foundation/Foundation.h>

@class MTSignal;
@class MTContext;

@interface MTBackupAddressSignals : NSObject

+ (MTSignal * _Nonnull)fetchBackupIps:(bool)isTestingEnvironment currentContext:(MTContext * _Nonnull)currentContext phoneNumber:(NSString * _Nullable)phoneNumber;

@end
