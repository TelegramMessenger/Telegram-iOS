#import <SSignalKit/SSignalKit.h>

@interface TGBridgeChatListSignals : NSObject

+ (SSignal *)chatListWithLimit:(NSUInteger)limit;

@end
