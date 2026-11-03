#import <Foundation/Foundation.h>
#import <MtProtoKit/MTMessageService.h>
#import <MtProtoKit/MTDatacenterAuthInfo.h>

@class MTRpcError;
@class MTProto;

@interface MTBindKeyMessageService : NSObject <MTMessageService>

- (instancetype)initWithPersistentKey:(MTDatacenterAuthKey *)persistentKey ephemeralKey:(MTDatacenterAuthKey *)ephemeralKey completion:(void (^)(bool success, MTRpcError *error))completion;

- (void)mtProtoAuthKeyRejected:(MTProto *)mtProto;
@end
