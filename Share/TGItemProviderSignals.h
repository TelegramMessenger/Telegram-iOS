#import <MTProtoKitDynamic/MTProtoKitDynamic.h>

@interface TGItemProviderSignals : NSObject

+ (NSArray<MTSignal *> *)itemSignalsForInputItems:(NSArray *)inputItems;
+ (NSData *)audioWaveform:(NSURL *)url;

@end
