#import <Foundation/Foundation.h>

@interface MTExportedAuthorizationData : NSObject

@property (nonatomic, strong, readonly) NSData *authorizationBytes;
@property (nonatomic, readonly) int64_t authorizationId;

- (instancetype)initWithAuthorizationBytes:(NSData *)authorizationBytes authorizationId:(int64_t)authorizationId;

@end
