#import <Foundation/Foundation.h>
#import <SSignalKit/SSignalKit.h>

@interface TGGifConverter : NSObject

+ (SSignal *)convertGifToMp4:(NSData *)data;

@end
