#import <Foundation/Foundation.h>

@interface MTExportedAuthorizationData : NSObject

@property (nonatomic, strong, readonly) NSData *authorizationBytes;
@property (nonatomic, readonly) int32_t authorizationId;

- (instancetype)initWithAuthorizationBytes:(NSData *)authorizationBytes authorizationId:(int32_t)authorizationId;

@end
