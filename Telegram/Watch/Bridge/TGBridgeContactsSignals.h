#import <SSignalKit/SSignalKit.h>

@interface TGBridgeContactsSignals : NSObject

+ (SSignal *)searchContactsWithQuery:(NSString *)query;

@end
