#import <Foundation/Foundation.h>

@interface MTServerDhParamsMessage : NSObject

@property (nonatomic, strong, readonly) NSData *nonce;
@property (nonatomic, strong, readonly) NSData *serverNonce;

@end

@interface MTServerDhParamsFailMessage : MTServerDhParamsMessage

@property (nonatomic, strong, readonly) NSData *nextNonceHash;

- (instancetype)initWithNonce:(NSData *)nonce serverNonce:(NSData *)serverNonce nextNonceHash:(NSData *)nextNonceHash;

@end

@interface MTServerDhParamsOkMessage : MTServerDhParamsMessage

@property (nonatomic, strong, readonly) NSData *encryptedResponse;

- (instancetype)initWithNonce:(NSData *)nonce serverNonce:(NSData *)serverNonce encryptedResponse:(NSData *)encryptedResponse;

@end
