#ifdef BUCK
#import <MTProtoKit/MTProtoKit.h>
#else
#import <MTProtoKitDynamic/MTProtoKitDynamic.h>
#endif

@interface TGItemProviderSignals : NSObject

+ (NSArray<MTSignal *> *)itemSignalsForInputItems:(NSArray *)inputItems;
+ (NSData *)audioWaveform:(NSURL *)url;

@end
