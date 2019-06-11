#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TGDataResource : NSObject

- (NSData *)data;
- (NSInputStream *)stream;
- (UIImage *)image;
- (bool)isImageDecoded;

- (instancetype)initWithData:(NSData *)data;
- (instancetype)initWithInputStream:(NSInputStream *)stream;
- (instancetype)initWithImage:(UIImage *)image decoded:(bool)decoded;

@end
