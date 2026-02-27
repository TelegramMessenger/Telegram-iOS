

#import <Foundation/Foundation.h>

@interface TGVideoInfo : NSObject <NSCoding>

- (void)addVideoWithQuality:(int)quality url:(NSString *)url size:(int)size;
- (NSString *)urlWithQuality:(int)quality actualQuality:(int *)actualQuality actualSize:(int *)actualSize;

- (void)serialize:(NSMutableData *)data;
+ (TGVideoInfo *)deserialize:(NSInputStream *)is;

@end
