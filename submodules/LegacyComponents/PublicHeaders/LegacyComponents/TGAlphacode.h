#import <Foundation/Foundation.h>

@class SSignal;

@interface TGAlphacodeEntry : NSObject

@property (nonatomic, strong, readonly) NSString *emoji;
@property (nonatomic, strong, readonly) NSString *code;

- (instancetype)initWithEmoji:(NSString *)emoji code:(NSString *)code;

@end
