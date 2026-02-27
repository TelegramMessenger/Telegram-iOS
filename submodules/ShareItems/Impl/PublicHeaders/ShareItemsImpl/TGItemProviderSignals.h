#import <Foundation/Foundation.h>

@class MTSignal;

@interface TGItemProviderSignals : NSObject

+ (NSArray<MTSignal *> *)itemSignalsForInputItems:(NSArray *)inputItems;
+ (NSData *)audioWaveform:(NSURL *)url;

@end
