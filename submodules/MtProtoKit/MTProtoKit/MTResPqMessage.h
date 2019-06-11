#import <Foundation/Foundation.h>

@interface MTResPqMessage : NSObject

@property (nonatomic, strong, readonly) NSData *nonce;
@property (nonatomic, strong, readonly) NSData *serverNonce;
@property (nonatomic, strong, readonly) NSData *pq;
@property (nonatomic, strong, readonly) NSArray *serverPublicKeyFingerprints;

- (instancetype)initWithNonce:(NSData *)nonce serverNonce:(NSData *)serverNonce pq:(NSData *)pq serverPublicKeyFingerprints:(NSArray *)serverPublicKeyFingerprints;

@end
