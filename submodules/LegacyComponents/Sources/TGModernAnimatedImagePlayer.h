#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TGModernAnimatedImagePlayer : NSObject

@property (nonatomic, copy) void (^frameReady)(UIImage *);

- (instancetype)initWithSize:(CGSize)size renderSize:(CGSize)renderSize path:(NSString *)path;
- (instancetype)initWithSize:(CGSize)size data:(NSData *)data;

- (void)play;
- (void)stop;
- (void)pause;

@end
