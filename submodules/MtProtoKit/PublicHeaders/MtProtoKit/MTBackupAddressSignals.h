#import <Foundation/Foundation.h>

@class MTSignal;
@class MTContext;

@interface MTBackupAddressSignals : NSObject

+ (MTSignal * _Nonnull)fetchBackupIps:(bool)isTestingEnvironment currentContext:(MTContext * _Nonnull)currentContext additionalSource:(MTSignal * _Nullable)additionalSource phoneNumber:(NSString * _Nullable)phoneNumber mainDatacenterId:(NSInteger)mainDatacenterId;

@end
