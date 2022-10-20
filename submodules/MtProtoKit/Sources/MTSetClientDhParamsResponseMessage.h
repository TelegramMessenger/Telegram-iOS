#import <Foundation/Foundation.h>

@interface MTSetClientDhParamsResponseMessage : NSObject

@property (nonatomic, strong, readonly) NSData *nonce;
@property (nonatomic, strong, readonly) NSData *serverNonce;

@end

@interface MTSetClientDhParamsResponseOkMessage : MTSetClientDhParamsResponseMessage

@property (nonatomic, strong, readonly) NSData *nextNonceHash1;

- (instancetype)initWithNonce:(NSData *)nonce serverNonce:(NSData *)serverNonce nextNonceHash1:(NSData *)nextNonceHash1;

@end

@interface MTSetClientDhParamsResponseRetryMessage : MTSetClientDhParamsResponseMessage

@property (nonatomic, strong, readonly) NSData *nextNonceHash2;

- (instancetype)initWithNonce:(NSData *)nonce serverNonce:(NSData *)serverNonce nextNonceHash2:(NSData *)newNonceHash2;

@end

@interface MTSetClientDhParamsResponseFailMessage : MTSetClientDhParamsResponseMessage

@property (nonatomic, strong, readonly) NSData *nextNonceHash3;

- (instancetype)initWithNonce:(NSData *)nonce serverNonce:(NSData *)serverNonce nextNonceHash3:(NSData *)newNonceHash3;

@end