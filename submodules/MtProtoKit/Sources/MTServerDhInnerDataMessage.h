#import <Foundation/Foundation.h>

@interface MTServerDhInnerDataMessage : NSObject

@property (nonatomic, strong, readonly) NSData *nonce;
@property (nonatomic, strong, readonly) NSData *serverNonce;
@property (nonatomic, readonly) int32_t g;
@property (nonatomic, strong, readonly) NSData *dhPrime;
@property (nonatomic, strong, readonly) NSData *gA;
@property (nonatomic, readonly) int32_t serverTime;

- (instancetype)initWithNonce:(NSData *)nonce serverNonce:(NSData *)serverNonce g:(int32_t)g dhPrime:(NSData *)dhPrime gA:(NSData *)gA serverTime:(int32_t)serverTime;

@end
